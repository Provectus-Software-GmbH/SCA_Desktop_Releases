#!/bin/bash
set -euo pipefail

REPO_OWNER="${SCA_GITHUB_OWNER:-Provectus-Software-GmbH}"
REPO_NAME="${SCA_GITHUB_REPO:-SCA_Desktop_Releases}"
APP_PATH="${SCA_APP_PATH:-/Applications/SecureContacts.app}"
EXPECTED_BUNDLE_ID="de.provectus.SecureContactsDesktop"
EXPECTED_SIGNER="Developer ID Installer: Provectus Software GmbH (572S9T76X8)"
CACHE_ROOT="${SCA_UPDATE_CACHE:-/Library/Application Support/SecureContacts/Updater}"
LOG_ROOT="${SCA_UPDATE_LOG:-/Library/Logs/SecureContacts}"
LOCK_PATH="${SCA_UPDATE_LOCK:-/var/run/securecontacts-update.lock}"
CURL_TIMEOUT="${SCA_CURL_TIMEOUT:-30}"

PKG_PATH=""
WORK_PATH=""
LOCK_ACQUIRED=false

usage() {
  cat <<'EOF'
Usage: Install-Secure-Contacts.sh [--check-only] [--help]

Checks the installed Secure Contacts version against the latest stable ARM64
GitHub release. Downloads, validates, and installs a newer PKG when needed.
This script does not publish to Microsoft Graph or remove application data.

Environment overrides:
  SCA_GITHUB_OWNER       GitHub owner (default: Provectus-Software-GmbH)
  SCA_GITHUB_REPO        GitHub repository (default: SCA_Desktop_Releases)
  SCA_APP_PATH           Application path (default: /Applications/SecureContacts.app)
  SCA_UPDATE_CACHE       Root-writable cache directory
  SCA_UPDATE_LOG         Log directory
  SCA_UPDATE_LOCK        Lock path
  SCA_CURL_TIMEOUT       curl connect/max request timeout in seconds
EOF
}

CHECK_ONLY=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --check-only)
      CHECK_ONLY=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 1
  }
}

require_command curl
require_command file
require_command find
require_command grep
require_command lsof
require_command mktemp
require_command pkgutil
require_command shasum
require_command spctl
[ -x /usr/libexec/PlistBuddy ] || {
  echo "/usr/libexec/PlistBuddy is required" >&2
  exit 1
}
[ -x /usr/sbin/installer ] || {
  echo "/usr/sbin/installer is required" >&2
  exit 1
}

host_architecture=$(/usr/bin/uname -m)
[ "$host_architecture" = "arm64" ] || {
  echo "Secure Contacts updater requires an Apple silicon Mac; detected: $host_architecture" >&2
  exit 1
}

mkdir -p "$CACHE_ROOT" "$LOG_ROOT"
LOG_PATH="$LOG_ROOT/update-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_PATH") 2>&1

cleanup() {
  if [ -n "$WORK_PATH" ] && [ -d "$WORK_PATH" ]; then
    rm -rf "$WORK_PATH"
  fi
  if [ "$LOCK_ACQUIRED" = true ]; then
    rmdir "$LOCK_PATH" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if ! mkdir "$LOCK_PATH" 2>/dev/null; then
  echo "Another Secure Contacts update is already running; exiting successfully."
  exit 0
fi
LOCK_ACQUIRED=true

version_parts() {
  local version="$1"
  version="${version#v}"
  if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    return 1
  fi
  local major=0 minor=0 patch=0
  IFS='.' read -r major minor patch <<EOF
$version
EOF
  printf '%d %d %d\n' "$major" "${minor:-0}" "${patch:-0}"
}

compare_versions() {
  local installed_parts target_parts installed_value target_value
  installed_parts=$(version_parts "$1") || return 2
  target_parts=$(version_parts "$2") || return 2
  installed_value=$(printf '%s\n' "$installed_parts" | awk '{ printf "%d%09d%09d", $1, $2, $3 }')
  target_value=$(printf '%s\n' "$target_parts" | awk '{ printf "%d%09d%09d", $1, $2, $3 }')
  if [ "$installed_value" -lt "$target_value" ]; then
    return 0
  fi
  if [ "$installed_value" -eq "$target_value" ]; then
    return 1
  fi
  return 2
}

read_app_value() {
  /usr/libexec/PlistBuddy -c "Print:$2" "$1" 2>/dev/null
}

installed_version=""
installed_bundle_id=""
app_info="$APP_PATH/Contents/Info.plist"
if [ -f "$app_info" ]; then
  installed_version=$(read_app_value "$app_info" CFBundleShortVersionString || true)
  installed_bundle_id=$(read_app_value "$app_info" CFBundleIdentifier || true)
  [ "$installed_bundle_id" = "$EXPECTED_BUNDLE_ID" ] || {
    echo "Installed application has unexpected bundle ID: ${installed_bundle_id:-<missing>}" >&2
    exit 1
  }
  version_parts "$installed_version" >/dev/null || {
    echo "Installed application has an invalid version: ${installed_version:-<missing>}" >&2
    exit 1
  }
  echo "Installed version: $installed_version"
else
  echo "Secure Contacts is not installed."
fi

latest_url="https://github.com/$REPO_OWNER/$REPO_NAME/releases/latest"
tag_url=$(curl --fail --silent --show-error --location --max-time "$CURL_TIMEOUT" \
  --output /dev/null --write-out '%{url_effective}' "$latest_url")
release_tag=$(printf '%s\n' "$tag_url" | sed -n 's#.*/tag/##p')
release_version="${release_tag#v}"
version_parts "$release_version" >/dev/null || {
  echo "Latest release tag is not a supported stable version: $release_tag" >&2
  exit 1
}

if [ -n "$installed_version" ]; then
  if compare_versions "$installed_version" "$release_version"; then
    echo "Update available: $installed_version -> $release_version"
  else
    comparison_status=$?
    if [ "$comparison_status" -eq 1 ]; then
      echo "Secure Contacts $installed_version is already current."
      exit 0
    fi
    echo "Refusing to downgrade Secure Contacts from $installed_version to $release_version." >&2
    exit 1
  fi
else
  echo "Latest release: $release_version"
fi

if [ "$CHECK_ONLY" = true ]; then
  echo "Check-only mode: installation skipped."
  exit 0
fi

bundle_processes() {
  local lsof_output

  lsof_output=$(/usr/sbin/lsof -n -d txt -F pn 2>/dev/null || true)
  printf '%s\n' "$lsof_output" | /usr/bin/awk -v prefix="$APP_PATH/Contents/" '
    /^p[0-9]+$/ { pid = substr($0, 2); next }
    /^n/ {
      path = substr($0, 2)
      if (pid != "" && index(path, prefix) == 1) {
        print pid "|" path
      }
    }
  '
}

running_bundle_processes="$(bundle_processes)"
if [ -n "$running_bundle_processes" ]; then
  while IFS='|' read -r process_id executable_path; do
    [ -n "$process_id" ] || continue
    current_process_path=$(/usr/sbin/lsof -n -a -p "$process_id" -d txt -F n 2>/dev/null | /usr/bin/sed -n 's/^n//p' | /usr/bin/head -1 || true)
    if [ "$current_process_path" = "$executable_path" ] && [[ "$current_process_path" == "$APP_PATH/Contents/"* ]]; then
      echo "Secure Contacts is running from the application bundle (PID $process_id). Close it before retrying the update." >&2
      exit 1
    fi
  done <<< "$running_bundle_processes"
fi

pkg_name="SecureContacts-${release_version}-arm64.pkg"
checksum_name="${pkg_name}.sha256"
WORK_PATH=$(mktemp -d "$CACHE_ROOT/work.XXXXXX")
PKG_PATH="$WORK_PATH/$pkg_name"
checksum_path="$WORK_PATH/$checksum_name"
base_url="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$release_tag"

echo "Downloading $pkg_name"
curl --fail --silent --show-error --location --max-time "$CURL_TIMEOUT" \
  --output "$PKG_PATH" "$base_url/$pkg_name"
curl --fail --silent --show-error --location --max-time "$CURL_TIMEOUT" \
  --output "$checksum_path" "$base_url/$checksum_name"

(
  cd "$WORK_PATH"
  shasum -a 256 -c "$checksum_name"
)

signature_output=$(pkgutil --check-signature "$PKG_PATH")
printf '%s\n' "$signature_output" | grep -F "$EXPECTED_SIGNER" >/dev/null || {
  echo "Unexpected package signer" >&2
  printf '%s\n' "$signature_output" >&2
  exit 1
}
printf '%s\n' "$signature_output" | grep -F 'Developer ID Certification Authority' >/dev/null || {
  echo "Expected Developer ID Certification Authority missing" >&2
  exit 1
}
printf '%s\n' "$signature_output" | grep -F 'Apple Root CA' >/dev/null || {
  echo "Expected Apple Root CA missing" >&2
  exit 1
}
spctl --assess --type install --verbose=4 "$PKG_PATH"

echo "Inspecting package metadata"
expanded_path="$WORK_PATH/expanded"
pkgutil --expand-full "$PKG_PATH" "$expanded_path"
info_path=""
matching_info_count=0
while IFS= read -r candidate_info_path; do
  candidate_bundle_id=$(read_app_value "$candidate_info_path" CFBundleIdentifier || true)
  if [ "$candidate_bundle_id" = "$EXPECTED_BUNDLE_ID" ]; then
    matching_info_count=$((matching_info_count + 1))
    info_path="$candidate_info_path"
  fi
done < <(find "$expanded_path" -type f -path '*/Contents/Info.plist' -not -path '*/Frameworks/*' -print | LC_ALL=C sort)

if [ "$matching_info_count" -eq 0 ]; then
  echo "No application Info.plist with bundle ID $EXPECTED_BUNDLE_ID found in package" >&2
  exit 1
fi
if [ "$matching_info_count" -ne 1 ]; then
  echo "Multiple application Info.plist files with bundle ID $EXPECTED_BUNDLE_ID found in package" >&2
  exit 1
fi
package_bundle_id=$(read_app_value "$info_path" CFBundleIdentifier)
package_version=$(read_app_value "$info_path" CFBundleShortVersionString)
executable_name=$(read_app_value "$info_path" CFBundleExecutable)
[ "$package_bundle_id" = "$EXPECTED_BUNDLE_ID" ] || { echo "Unexpected package bundle ID: $package_bundle_id" >&2; exit 1; }
[ "$package_version" = "$release_version" ] || { echo "Package version $package_version does not match release $release_version" >&2; exit 1; }
package_executable=$(dirname "$info_path")/MacOS/$executable_name
[ -f "$package_executable" ] || { echo "Package executable not found: $package_executable" >&2; exit 1; }
file_output=$(file "$package_executable")
printf '%s\n' "$file_output" | grep -E 'arm64|Apple silicon' >/dev/null || {
  echo "Package executable is not identified as ARM64" >&2
  printf '%s\n' "$file_output" >&2
  exit 1
}

installer_log="$LOG_ROOT/install-${release_version}-$(date +%Y%m%d-%H%M%S).log"
echo "Installing Secure Contacts $release_version"
/usr/sbin/installer -pkg "$PKG_PATH" -target / 2>&1 | tee "$installer_log"
installer_status=${PIPESTATUS[0]}
if [ "$installer_status" -ne 0 ]; then
  echo "PKG installation failed with exit code $installer_status. See $installer_log" >&2
  exit "$installer_status"
fi

echo "Secure Contacts $release_version installed successfully."
