#!/bin/bash

set -u
set -o pipefail

readonly APP_PATH="/Applications/SecureContacts.app"
readonly APP_BUNDLE_ID="de.provectus.SecureContactsDesktop"
readonly APP_EXECUTABLE="SecureContacts"
readonly MANAGED_PREFERENCE_PATH="/Library/Managed Preferences/de.provectus.SecureContactsDesktop.plist"
readonly MIN_SUPPORTED_MACOS_MAJOR=15

# Populate both values from a signed production Developer ID artifact before deployment.
readonly INTUNE_MODE="REPLACE_WITH_APPLICATION_ONLY_OR_COMPLETE_PURGE"
readonly EXPECTED_TEAM_ID="REPLACE_WITH_PRODUCTION_TEAM_ID"
readonly EXPECTED_DESIGNATED_REQUIREMENT="REPLACE_WITH_PRODUCTION_DESIGNATED_REQUIREMENT"

readonly EXIT_USAGE=64
readonly EXIT_NOT_ROOT=77
readonly EXIT_IDENTITY_CONFIGURATION=78
readonly EXIT_PREFLIGHT=80
readonly EXIT_PROCESS=81
readonly EXIT_DELETE=82
readonly EXIT_VERIFY=83

MODE=""
DRY_RUN=false
RUN_ID="$(/usr/bin/uuidgen 2>/dev/null || printf '%s-%s' "$(/bin/date -u +%Y%m%dT%H%M%SZ)" "$$")"
PREFERENCE_SNAPSHOT_BEFORE=""
APP_WAS_PRESENT=false
BUNDLE_FINGERPRINT=""
ELIGIBLE_USERS=()
ELIGIBLE_UIDS=()
ELIGIBLE_HOMES=()
VERIFIED_PROCESSES=()

json_escape() {
	local value="$1"
	value="${value//\\/\\\\}"
	value="${value//\"/\\\"}"
	value="${value//$'\n'/\\n}"
	value="${value//$'\r'/\\r}"
	value="${value//$'\t'/\\t}"
	printf '%s' "$value"
}

emit_event() {
	local level="$1"
	local action="$2"
	local result="$3"
	local reason="$4"
	local target="${5:-}"
	local user_name="${6:-}"
	local timestamp
	local event

	timestamp="$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)"
	event="{\"timestamp\":\"$(json_escape "$timestamp")\",\"runId\":\"$(json_escape "$RUN_ID")\",\"mode\":\"$(json_escape "${MODE:-unknown}")\",\"dryRun\":${DRY_RUN},\"level\":\"$(json_escape "$level")\",\"action\":\"$(json_escape "$action")\",\"result\":\"$(json_escape "$result")\",\"reason\":\"$(json_escape "$reason")\",\"target\":\"$(json_escape "$target")\",\"user\":\"$(json_escape "$user_name")\"}"
	printf '%s\n' "$event"
}

fail() {
	local exit_code="$1"
	local action="$2"
	local reason="$3"
	local target="${4:-}"
	emit_event "error" "$action" "failed" "$reason" "$target"
	exit "$exit_code"
}

usage() {
	cat <<'EOF'
Usage: uninstall-secure-contacts.sh <application-only|complete-purge> [--dry-run]

  application-only  Remove the verified application bundle and preserve user data/logs.
  complete-purge    Remove the verified bundle plus Secure Contacts Data/logs for all eligible users.
  --dry-run         Perform preflight and report planned actions without changing the device.
EOF
}

parse_arguments() {
	if [[ $# -eq 0 ]]; then
		case "$INTUNE_MODE" in
			application-only|complete-purge)
				MODE="$INTUNE_MODE"
				return
				;;
		*)
			usage
			exit "$EXIT_USAGE"
			;;
		esac
	fi

	if [[ $# -gt 2 ]]; then
		usage
		exit "$EXIT_USAGE"
	fi

	case "$1" in
		application-only|complete-purge)
			MODE="$1"
			;;
		*)
			usage
			exit "$EXIT_USAGE"
			;;
	esac

	if [[ $# -eq 2 ]]; then
		if [[ "$2" != "--dry-run" ]]; then
			usage
			exit "$EXIT_USAGE"
		fi
		DRY_RUN=true
	fi
}

require_supported_runtime() {
	local macos_version
	local macos_major

	if [[ "$(/usr/bin/uname -s)" != "Darwin" ]]; then
		fail "$EXIT_PREFLIGHT" "runtime_preflight" "unsupported_platform" "$(/usr/bin/uname -s)"
	fi

	macos_version="$(/usr/bin/sw_vers -productVersion 2>/dev/null)" || fail "$EXIT_PREFLIGHT" "runtime_preflight" "macos_version_unavailable"
	macos_major="${macos_version%%.*}"
	[[ "$macos_major" =~ ^[0-9]+$ && "$macos_major" -ge "$MIN_SUPPORTED_MACOS_MAJOR" ]] || fail "$EXIT_PREFLIGHT" "runtime_preflight" "unsupported_macos_version" "$macos_version"

	if [[ "$DRY_RUN" == false && "$EUID" -ne 0 ]]; then
		fail "$EXIT_NOT_ROOT" "runtime_preflight" "root_required"
	fi
}

require_identity_configuration() {
	if [[ "$EXPECTED_TEAM_ID" == REPLACE_WITH_* || "$EXPECTED_DESIGNATED_REQUIREMENT" == REPLACE_WITH_* ]]; then
		fail "$EXIT_IDENTITY_CONFIGURATION" "identity_preflight" "identity_configuration_missing" "$APP_PATH"
	fi
}

read_plist_value() {
	/usr/bin/plutil -extract "$1" raw -o - "$2" 2>/dev/null
}

canonical_directory() {
	local directory="$1"
	(
		cd -P "$directory" 2>/dev/null && /bin/pwd -P
	)
}

validate_bundle() {
	local canonical_parent
	local bundle_id
	local executable_name
	local package_type
	local team_id
	local owner_uid
	local mode

	if [[ -L "$APP_PATH" ]]; then
		fail "$EXIT_PREFLIGHT" "bundle_preflight" "bundle_is_symlink" "$APP_PATH"
	fi

	if [[ ! -e "$APP_PATH" ]]; then
		emit_event "info" "bundle_preflight" "already_absent" "bundle_not_present" "$APP_PATH"
		return
	fi

	APP_WAS_PRESENT=true
	[[ -d "$APP_PATH" ]] || fail "$EXIT_PREFLIGHT" "bundle_preflight" "bundle_not_directory" "$APP_PATH"
	canonical_parent="$(canonical_directory "$(/usr/bin/dirname "$APP_PATH")")"
	[[ "$canonical_parent/$(/usr/bin/basename "$APP_PATH")" == "$APP_PATH" ]] || fail "$EXIT_PREFLIGHT" "bundle_preflight" "unexpected_canonical_path" "$APP_PATH"
	[[ -f "$APP_PATH/Contents/Info.plist" ]] || fail "$EXIT_PREFLIGHT" "bundle_preflight" "info_plist_missing" "$APP_PATH"

	bundle_id="$(read_plist_value CFBundleIdentifier "$APP_PATH/Contents/Info.plist")"
	executable_name="$(read_plist_value CFBundleExecutable "$APP_PATH/Contents/Info.plist")"
	package_type="$(read_plist_value CFBundlePackageType "$APP_PATH/Contents/Info.plist")"
	[[ "$bundle_id" == "$APP_BUNDLE_ID" ]] || fail "$EXIT_PREFLIGHT" "bundle_preflight" "bundle_identifier_mismatch" "$APP_PATH"
	[[ "$executable_name" == "$APP_EXECUTABLE" ]] || fail "$EXIT_PREFLIGHT" "bundle_preflight" "bundle_executable_mismatch" "$APP_PATH"
	[[ "$package_type" == "APPL" ]] || fail "$EXIT_PREFLIGHT" "bundle_preflight" "bundle_package_type_mismatch" "$APP_PATH"
	[[ -f "$APP_PATH/Contents/MacOS/$APP_EXECUTABLE" && -x "$APP_PATH/Contents/MacOS/$APP_EXECUTABLE" ]] || fail "$EXIT_PREFLIGHT" "bundle_preflight" "bundle_executable_missing" "$APP_PATH"

	owner_uid="$(/usr/bin/stat -f '%u' "$APP_PATH")"
	mode="$(/usr/bin/stat -f '%OLp' "$APP_PATH")"
	[[ "$owner_uid" == "0" ]] || fail "$EXIT_PREFLIGHT" "bundle_preflight" "unexpected_bundle_owner" "$APP_PATH"
	if (( (8#$mode & 0002) != 0 )); then
		fail "$EXIT_PREFLIGHT" "bundle_preflight" "bundle_world_writable" "$APP_PATH"
	fi

	/usr/bin/codesign --verify --deep --strict "$APP_PATH" >/dev/null 2>&1 || fail "$EXIT_PREFLIGHT" "bundle_preflight" "code_signature_invalid" "$APP_PATH"
	team_id="$(/usr/bin/codesign -dv --verbose=4 "$APP_PATH" 2>&1 | /usr/bin/awk -F= '/^TeamIdentifier=/{print $2; exit}')"
	[[ "$team_id" == "$EXPECTED_TEAM_ID" ]] || fail "$EXIT_PREFLIGHT" "bundle_preflight" "team_identifier_mismatch" "$APP_PATH"
	/usr/bin/codesign --verify --deep --strict -R="$EXPECTED_DESIGNATED_REQUIREMENT" "$APP_PATH" >/dev/null 2>&1 || fail "$EXIT_PREFLIGHT" "bundle_preflight" "designated_requirement_mismatch" "$APP_PATH"
	BUNDLE_FINGERPRINT="$(/usr/bin/stat -f '%d|%i|%u|%g|%OLp|%m' "$APP_PATH")" || fail "$EXIT_PREFLIGHT" "bundle_preflight" "bundle_fingerprint_failed" "$APP_PATH"

	emit_event "info" "bundle_preflight" "validated" "bundle_identity_verified" "$APP_PATH"
}

revalidate_bundle_before_removal() {
	local previous_fingerprint="$BUNDLE_FINGERPRINT"
	local current_fingerprint

	[[ "$APP_WAS_PRESENT" == true ]] || return
	[[ ! -L "$APP_PATH" && -d "$APP_PATH" ]] || fail "$EXIT_PREFLIGHT" "bundle_revalidation" "bundle_replaced_before_removal" "$APP_PATH"
	current_fingerprint="$(/usr/bin/stat -f '%d|%i|%u|%g|%OLp|%m' "$APP_PATH")" || fail "$EXIT_PREFLIGHT" "bundle_revalidation" "bundle_fingerprint_failed" "$APP_PATH"
	[[ "$current_fingerprint" == "$previous_fingerprint" ]] || fail "$EXIT_PREFLIGHT" "bundle_revalidation" "bundle_identity_changed" "$APP_PATH"
	/usr/bin/codesign --verify --deep --strict -R="$EXPECTED_DESIGNATED_REQUIREMENT" "$APP_PATH" >/dev/null 2>&1 || fail "$EXIT_PREFLIGHT" "bundle_revalidation" "bundle_signature_changed" "$APP_PATH"
}

preference_snapshot() {
	local hash
	local metadata

	if [[ -L "$MANAGED_PREFERENCE_PATH" ]]; then
		return 1
	fi

	if [[ ! -e "$MANAGED_PREFERENCE_PATH" ]]; then
		printf 'absent'
		return
	fi

	hash="$(/usr/bin/shasum -a 256 "$MANAGED_PREFERENCE_PATH" | /usr/bin/awk '{print $1}')" || return 1
	metadata="$(/usr/bin/stat -f '%d|%i|%u|%g|%OLp|%m|%z' "$MANAGED_PREFERENCE_PATH")" || return 1
	[[ -n "$hash" && -n "$metadata" ]] || return 1
	printf '%s|%s' "$hash" "$metadata"
}

validate_home_path() {
	local home_path="$1"
	local expected_uid="$2"
	local canonical_home
	local owner_uid

	[[ "$home_path" == /Users/* ]] || return 1
	[[ "$home_path" != "/Users/Shared" && "$home_path" != "/Users/Guest" ]] || return 1
	[[ ! -L "$home_path" && -d "$home_path" ]] || return 1
	canonical_home="$(canonical_directory "$home_path")" || return 1
	[[ "$canonical_home" == "$home_path" ]] || return 1
	[[ "$(/usr/bin/dirname "$canonical_home")" == "/Users" ]] || return 1
	owner_uid="$(/usr/bin/stat -f '%u' "$canonical_home")" || return 1
	[[ "$owner_uid" == "$expected_uid" ]] || return 1
	return 0
}

enumerate_eligible_users() {
	local user_name
	local uid
	local home_path
	local user_records
	local existing_home

	user_records="$(/usr/bin/dscl . -list /Users UniqueID 2>/dev/null)" || fail "$EXIT_PREFLIGHT" "user_preflight" "directory_service_enumeration_failed"
	[[ -n "$user_records" ]] || fail "$EXIT_PREFLIGHT" "user_preflight" "directory_service_returned_no_users"

	while IFS=$' \t' read -r user_name uid; do
		[[ "$uid" =~ ^[0-9]+$ ]] || continue
		(( uid >= 500 )) || continue
		[[ "$user_name" != "nobody" ]] || continue
		home_path="$(/usr/bin/dscl . -read "/Users/$user_name" NFSHomeDirectory 2>/dev/null | /usr/bin/sed -n 's/^NFSHomeDirectory: //p')" || fail "$EXIT_PREFLIGHT" "user_preflight" "home_directory_lookup_failed" "$user_name"
		if ! validate_home_path "$home_path" "$uid"; then
			if [[ "$MODE" == "complete-purge" ]]; then
				fail "$EXIT_PREFLIGHT" "user_preflight" "unsafe_or_unavailable_home" "$home_path"
			fi
			emit_event "warning" "user_preflight" "skipped" "unsafe_or_unavailable_home" "$home_path" "$user_name"
			continue
		fi
		for existing_home in "${ELIGIBLE_HOMES[@]}"; do
			[[ "$existing_home" != "$home_path" ]] || fail "$EXIT_PREFLIGHT" "user_preflight" "duplicate_home_directory" "$home_path"
		done

		ELIGIBLE_USERS+=("$user_name")
		ELIGIBLE_UIDS+=("$uid")
		ELIGIBLE_HOMES+=("$home_path")
		emit_event "info" "user_preflight" "validated" "eligible_local_user" "$home_path" "$user_name"
	done <<< "$user_records"
}

validate_cleanup_target() {
	local home_path="$1"
	local target_path="$2"
	local relative_path="${target_path#"$home_path"/}"
	local current_path="$home_path"
	local component
	local home_device
	local component_device

	[[ "$target_path" == "$home_path/"* && "$target_path" != "$home_path" ]] || return 1
	home_device="$(/usr/bin/stat -f '%d' "$home_path")" || return 1
	IFS='/' read -r -a components <<< "$relative_path"
	for component in "${components[@]}"; do
		[[ -n "$component" && "$component" != "." && "$component" != ".." ]] || return 1
		current_path="$current_path/$component"
		if [[ -L "$current_path" ]]; then
			return 1
		fi
		if [[ -e "$current_path" ]]; then
			component_device="$(/usr/bin/stat -f '%d' "$current_path")" || return 1
			[[ "$component_device" == "$home_device" ]] || return 1
		fi
	done
	return 0
}

preflight_cleanup_targets() {
	local index
	local home_path
	local data_path
	local logs_path

	[[ "$MODE" == "complete-purge" ]] || return
	for index in "${!ELIGIBLE_USERS[@]}"; do
		home_path="${ELIGIBLE_HOMES[$index]}"
		data_path="$home_path/Library/Application Support/SecureContacts/Data"
		logs_path="$home_path/Library/Logs/SecureContacts"
		validate_cleanup_target "$home_path" "$data_path" || fail "$EXIT_PREFLIGHT" "data_preflight" "unsafe_cleanup_target" "$data_path"
		validate_cleanup_target "$home_path" "$logs_path" || fail "$EXIT_PREFLIGHT" "logs_preflight" "unsafe_cleanup_target" "$logs_path"
	done
}

scan_verified_processes() {
	local lsof_output
	local process_records
	local process_record

	VERIFIED_PROCESSES=()
	lsof_output="$(/usr/sbin/lsof -n -d txt -F pn 2>/dev/null)" || fail "$EXIT_PROCESS" "process_discovery" "lsof_scan_failed"
	process_records="$(printf '%s\n' "$lsof_output" | /usr/bin/awk -v prefix="$APP_PATH/Contents/" '
		/^p[0-9]+$/ { pid = substr($0, 2); first_text = 1; next }
		/^n/ && first_text {
			path = substr($0, 2)
			first_text = 0
			if (pid != "" && index(path, prefix) == 1) {
				print pid "|" path
			}
		}
	')" || fail "$EXIT_PROCESS" "process_discovery" "process_scan_parse_failed"

	while IFS= read -r process_record; do
		[[ -n "$process_record" ]] && VERIFIED_PROCESSES+=("$process_record")
	done <<< "$process_records"
}

get_verified_pid_path() {
	local pid="$1"
	local expected_path="$2"
	local lsof_output
	local matching_path

	if ! lsof_output="$(/usr/sbin/lsof -n -a -p "$pid" -d txt -F n 2>/dev/null)"; then
		/bin/kill -0 "$pid" 2>/dev/null || return 2
		return 1
	fi

	matching_path="$(printf '%s\n' "$lsof_output" | /usr/bin/sed -n 's/^n//p' | /usr/bin/head -1)"
	[[ "$matching_path" == "$expected_path" ]] || return 1
	printf '%s' "$matching_path"
}

kill_verified_processes() {
	local pid
	local executable_path
	local current_path
	local deadline
	local verification_status

	scan_verified_processes
	if [[ ${#VERIFIED_PROCESSES[@]} -eq 0 ]]; then
		emit_event "info" "process_termination" "already_absent" "no_bundle_owned_processes" "$APP_PATH"
		return
	fi

	if [[ "$DRY_RUN" == true ]]; then
		for process_record in "${VERIFIED_PROCESSES[@]}"; do
			emit_event "info" "process_termination" "planned" "verified_process_would_be_force_killed" "$process_record"
		done
		return
	fi

	for process_record in "${VERIFIED_PROCESSES[@]}"; do
		pid="${process_record%%|*}"
		executable_path="${process_record#*|}"
		current_path="$(get_verified_pid_path "$pid" "$executable_path")"
		verification_status=$?
		if [[ "$verification_status" -eq 2 ]]; then
			emit_event "info" "process_termination" "already_absent" "process_exited_before_signal" "$pid"
			continue
		fi
		if [[ "$verification_status" -ne 0 || "$current_path" != "$APP_PATH/Contents/"* ]]; then
			fail "$EXIT_PROCESS" "process_termination" "pid_identity_changed" "$pid"
		fi
		if ! /bin/kill -KILL "$pid" 2>/dev/null; then
			/bin/kill -0 "$pid" 2>/dev/null && fail "$EXIT_PROCESS" "process_termination" "sigkill_failed" "$pid"
			emit_event "info" "process_termination" "already_absent" "process_exited_during_signal" "$pid"
			continue
		fi
		emit_event "info" "process_termination" "signal_sent" "sigkill" "$pid"
	done

	deadline=$((SECONDS + 5))
	while (( SECONDS < deadline )); do
		scan_verified_processes
		[[ ${#VERIFIED_PROCESSES[@]} -eq 0 ]] && break
		/bin/sleep 1
	done

	scan_verified_processes
	[[ ${#VERIFIED_PROCESSES[@]} -eq 0 ]] || fail "$EXIT_PROCESS" "process_termination" "bundle_processes_survived" "${VERIFIED_PROCESSES[*]}"
	emit_event "info" "process_termination" "verified" "all_bundle_processes_absent" "$APP_PATH"
}

remove_path() {
	local target_path="$1"
	local category="$2"
	local user_name="${3:-}"

	if [[ -L "$target_path" ]]; then
		fail "$EXIT_PREFLIGHT" "$category" "target_is_symlink" "$target_path"
	fi

	if [[ ! -e "$target_path" ]]; then
		emit_event "info" "$category" "already_absent" "target_not_present" "$target_path" "$user_name"
		return
	fi

	if [[ "$DRY_RUN" == true ]]; then
		emit_event "info" "$category" "planned" "target_would_be_removed" "$target_path" "$user_name"
		return
	fi

	/usr/bin/find -x "$target_path" -depth -delete || fail "$EXIT_DELETE" "$category" "target_removal_failed" "$target_path"
	[[ ! -e "$target_path" ]] || fail "$EXIT_VERIFY" "$category" "target_still_present" "$target_path"
	emit_event "info" "$category" "removed" "target_absent_after_removal" "$target_path" "$user_name"
}

remove_user_data() {
	local index
	local user_name
	local uid
	local home_path
	local data_path
	local logs_path

	for index in "${!ELIGIBLE_USERS[@]}"; do
		user_name="${ELIGIBLE_USERS[$index]}"
		uid="${ELIGIBLE_UIDS[$index]}"
		home_path="${ELIGIBLE_HOMES[$index]}"
		data_path="$home_path/Library/Application Support/SecureContacts/Data"
		logs_path="$home_path/Library/Logs/SecureContacts"

		validate_home_path "$home_path" "$uid" || fail "$EXIT_PREFLIGHT" "data_removal" "user_home_changed" "$home_path"
		validate_cleanup_target "$home_path" "$data_path" || fail "$EXIT_PREFLIGHT" "data_removal" "unsafe_cleanup_target" "$data_path"
		remove_path "$data_path" "data_removal" "$user_name"

		validate_home_path "$home_path" "$uid" || fail "$EXIT_PREFLIGHT" "logs_removal" "user_home_changed" "$home_path"
		validate_cleanup_target "$home_path" "$logs_path" || fail "$EXIT_PREFLIGHT" "logs_removal" "unsafe_cleanup_target" "$logs_path"
		remove_path "$logs_path" "logs_removal" "$user_name"
	done
}

remove_legacy_login_item_for_console_user() {
	local console_user
	local console_uid

	[[ "$MODE" == "complete-purge" ]] || return
	console_user="$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"
	if [[ -z "$console_user" || "$console_user" == "root" || "$console_user" == "loginwindow" ]]; then
		emit_event "warning" "login_item_cleanup" "residual" "no_active_gui_user"
		return
	fi
	console_uid="$(/usr/bin/id -u "$console_user" 2>/dev/null || true)"
	if [[ ! "$console_uid" =~ ^[0-9]+$ ]]; then
		emit_event "warning" "login_item_cleanup" "residual" "console_user_uid_unavailable" "" "$console_user"
		return
	fi

	if [[ "$DRY_RUN" == true ]]; then
		emit_event "warning" "login_item_cleanup" "planned" "legacy_cleanup_only_modern_registration_may_remain" "$APP_PATH" "$console_user"
		return
	fi

	if /bin/launchctl asuser "$console_uid" /usr/bin/sudo -u "$console_user" /usr/bin/osascript - "$APP_PATH" <<'APPLESCRIPT'
on run argv
	set expectedPath to item 1 of argv
	tell application "System Events"
		repeat with loginItem in login items
			try
				if path of loginItem is expectedPath then delete loginItem
			end try
		end repeat
	end tell
end run
APPLESCRIPT
	then
		emit_event "warning" "login_item_cleanup" "best_effort_complete" "modern_registration_may_remain" "$APP_PATH" "$console_user"
	else
		emit_event "warning" "login_item_cleanup" "residual" "legacy_login_item_cleanup_failed" "$APP_PATH" "$console_user"
	fi
}

verify_managed_preference_unchanged() {
	local snapshot_after
	if ! snapshot_after="$(preference_snapshot)"; then
		fail "$EXIT_VERIFY" "managed_preference_verification" "managed_preference_snapshot_failed" "$MANAGED_PREFERENCE_PATH"
	fi
	[[ "$snapshot_after" == "$PREFERENCE_SNAPSHOT_BEFORE" ]] || fail "$EXIT_VERIFY" "managed_preference_verification" "managed_preference_changed" "$MANAGED_PREFERENCE_PATH"
	emit_event "info" "managed_preference_verification" "preserved" "managed_preference_unchanged" "$MANAGED_PREFERENCE_PATH"
}

main() {
	parse_arguments "$@"
	require_supported_runtime
	require_identity_configuration
	if ! PREFERENCE_SNAPSHOT_BEFORE="$(preference_snapshot)"; then
		fail "$EXIT_PREFLIGHT" "managed_preference_preflight" "managed_preference_snapshot_failed" "$MANAGED_PREFERENCE_PATH"
	fi
	validate_bundle
	if [[ "$MODE" == "complete-purge" ]]; then
		enumerate_eligible_users
		preflight_cleanup_targets
	fi
	emit_event "info" "uninstall" "started" "operation_started"
	kill_verified_processes

	if [[ "$MODE" == "complete-purge" ]]; then
		remove_legacy_login_item_for_console_user
		remove_user_data
	else
		emit_event "info" "data_removal" "preserved" "application_only_mode"
		emit_event "info" "logs_removal" "preserved" "application_only_mode"
		emit_event "warning" "login_item_cleanup" "residual" "application_only_preserves_login_item"
	fi

	revalidate_bundle_before_removal
	remove_path "$APP_PATH" "bundle_removal"
	verify_managed_preference_unchanged
	emit_event "info" "uninstall" "success" "operation_complete"
}

main "$@"