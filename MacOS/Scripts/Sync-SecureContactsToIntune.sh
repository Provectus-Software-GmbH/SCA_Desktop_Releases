#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALIDATOR="$SCRIPT_DIR/Invoke-SecureContactsAutoUpdate.sh"
OUTPUT_PATH="./artifacts"
MANIFEST_OUTPUT=""
DECISION_MANIFEST_OUTPUT=""
INTUNE_APP_ID="${INTUNE_APP_ID:-}"
GRAPH_ACCESS_TOKEN="${GRAPH_ACCESS_TOKEN:-}"
SKIP_RECIPE=false
PUBLISH=false
WHAT_IF=false

usage() {
  cat <<'EOF'
Usage: Sync-SecureContactsToIntune.sh [--output PATH] [--manifest-output PATH]
  [--decision-manifest-output PATH] [--app-id GUID]
  [--skip-recipe] [--publish] [--what-if]

Stages and validates one Secure Contacts ARM64 PKG. Validation is the default.
--what-if performs a read-only Microsoft Graph beta lookup and version decision.
Publishing is not yet implemented and always fails closed.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --output)
      [ "$#" -ge 2 ] || { echo "--output requires a path" >&2; exit 2; }
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --manifest-output)
      [ "$#" -ge 2 ] || { echo "--manifest-output requires a path" >&2; exit 2; }
      MANIFEST_OUTPUT="$2"
      shift 2
      ;;
    --decision-manifest-output)
      [ "$#" -ge 2 ] || { echo "--decision-manifest-output requires a path" >&2; exit 2; }
      DECISION_MANIFEST_OUTPUT="$2"
      shift 2
      ;;
    --app-id)
      [ "$#" -ge 2 ] || { echo "--app-id requires a GUID" >&2; exit 2; }
      INTUNE_APP_ID="$2"
      shift 2
      ;;
    --skip-recipe)
      SKIP_RECIPE=true
      shift
      ;;
    --publish)
      PUBLISH=true
      shift
      ;;
    --what-if)
      WHAT_IF=true
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

if [ "$WHAT_IF" = true ] && [ "$PUBLISH" != true ]; then
  echo "--what-if requires --publish" >&2
  exit 2
fi

if [ -z "$MANIFEST_OUTPUT" ]; then
  MANIFEST_OUTPUT="$OUTPUT_PATH/validation-manifest.json"
fi

if [ -z "$DECISION_MANIFEST_OUTPUT" ]; then
  DECISION_MANIFEST_OUTPUT="$OUTPUT_PATH/decision-manifest.json"
fi

mkdir -p "$OUTPUT_PATH"
validator_arguments=(--output "$OUTPUT_PATH" --manifest-output "$MANIFEST_OUTPUT")
if [ "$SKIP_RECIPE" = true ]; then
  validator_arguments+=(--skip-recipe)
fi

"$VALIDATOR" "${validator_arguments[@]}"

if [ "$PUBLISH" = true ] && [ "$WHAT_IF" != true ]; then
  echo "Graph publishing is not implemented for macOS PKG apps; refusing to continue." >&2
  exit 1
fi

if [ "$WHAT_IF" = true ]; then
  [ -n "$INTUNE_APP_ID" ] || { echo "--app-id or INTUNE_APP_ID is required for --what-if" >&2; exit 2; }
  [ -n "$GRAPH_ACCESS_TOKEN" ] || { echo "GRAPH_ACCESS_TOKEN is required for --what-if" >&2; exit 2; }
  printf '%s' "$INTUNE_APP_ID" | grep -Eq '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$' || {
    echo "Invalid Intune macOS app ID" >&2
    exit 2
  }

  command -v curl >/dev/null || { echo "curl is required for --what-if" >&2; exit 1; }
  [ -x /usr/bin/plutil ] || { echo "/usr/bin/plutil is required for --what-if" >&2; exit 1; }
  [ -x /usr/libexec/PlistBuddy ] || { echo "/usr/libexec/PlistBuddy is required for --what-if" >&2; exit 1; }

  graph_response=$(mktemp)
  graph_plist=$(mktemp)
  included_apps_plist=$(mktemp)
  graph_curl_config=$(mktemp)
  chmod 600 "$graph_curl_config"
  cleanup_graph_files() {
    rm -f "$graph_response" "$graph_plist" "$included_apps_plist" "$graph_curl_config"
  }
  trap cleanup_graph_files EXIT

  printf 'header = "Authorization: Bearer %s"\nheader = "Accept: application/json"\n' \
    "$GRAPH_ACCESS_TOKEN" > "$graph_curl_config"
  curl --fail --silent --show-error \
    --config "$graph_curl_config" \
    "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$INTUNE_APP_ID" \
    --output "$graph_response"
  /usr/bin/plutil -convert xml1 -o "$graph_plist" "$graph_response"

  graph_type=$(/usr/libexec/PlistBuddy -c 'Print:@odata.type' "$graph_plist" 2>/dev/null || true)
  [ "$graph_type" = '#microsoft.graph.macOSPkgApp' ] || {
    echo "Target app is not a macOSPkgApp (observed type: ${graph_type:-missing})" >&2
    exit 1
  }

  /usr/bin/plutil -extract includedApps xml1 -o "$included_apps_plist" "$graph_response"
  candidate_bundle_id=$(/usr/bin/plutil -extract BundleId raw -o - "$MANIFEST_OUTPUT")
  candidate_version=$(/usr/bin/plutil -extract ReleaseVersion raw -o - "$MANIFEST_OUTPUT")
  matching_count=0
  intune_version=""
  included_index=0
  while bundle_id=$(/usr/libexec/PlistBuddy -c "Print:$included_index:bundleId" "$included_apps_plist" 2>/dev/null); do
    bundle_version=$(/usr/libexec/PlistBuddy -c "Print:$included_index:bundleVersion" "$included_apps_plist" 2>/dev/null || true)
    if [ "$bundle_id" = "$candidate_bundle_id" ]; then
      matching_count=$((matching_count + 1))
      intune_version="$bundle_version"
    fi
    included_index=$((included_index + 1))
  done

  [ "$candidate_bundle_id" = 'de.provectus.SecureContactsDesktop' ] || { echo "Unexpected candidate bundle ID" >&2; exit 1; }
  [ "$matching_count" -eq 1 ] || { echo "Expected exactly one matching includedApps entry, found $matching_count" >&2; exit 1; }
  printf '%s\n' "$intune_version" | grep -Eq '^[0-9]+(\.[0-9]+)*$' || { echo "Invalid Intune bundle version" >&2; exit 1; }
  printf '%s\n' "$candidate_version" | grep -Eq '^[0-9]+(\.[0-9]+)*$' || { echo "Invalid candidate version" >&2; exit 1; }

  version_compare() {
    awk -v left="$1" -v right="$2" 'BEGIN {
      left_count = split(left, left_parts, "."); right_count = split(right, right_parts, ".");
      count = left_count > right_count ? left_count : right_count;
      for (i = 1; i <= count; i++) {
        left_value = (i <= left_count ? left_parts[i] : 0) + 0;
        right_value = (i <= right_count ? right_parts[i] : 0) + 0;
        if (left_value < right_value) { print -1; exit }
        if (left_value > right_value) { print 1; exit }
      }
      print 0
    }'
  }

  version_order=$(version_compare "$candidate_version" "$intune_version")
  if [ "$version_order" -lt 0 ]; then
    decision="RejectedDowngrade"
    echo "Candidate version $candidate_version is older than Intune version $intune_version" >&2
    exit 1
  elif [ "$version_order" -eq 0 ]; then
    decision="NoUpdateRequired"
  else
    decision="UpdateExistingApp"
  fi

  decision_plist=$(mktemp)
  /usr/bin/plutil -create xml1 "$decision_plist"
  /usr/bin/plutil -insert Decision -string "$decision" "$decision_plist"
  /usr/bin/plutil -insert IntuneAppId -string "$INTUNE_APP_ID" "$decision_plist"
  /usr/bin/plutil -insert GraphEndpoint -string "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$INTUNE_APP_ID" "$decision_plist"
  /usr/bin/plutil -insert ResourceType -string "$graph_type" "$decision_plist"
  /usr/bin/plutil -insert CandidateVersion -string "$candidate_version" "$decision_plist"
  /usr/bin/plutil -insert IntuneBundleVersion -string "$intune_version" "$decision_plist"
  /usr/bin/plutil -insert BundleId -string "$candidate_bundle_id" "$decision_plist"
  /usr/bin/plutil -insert CreatedUtc -date "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$decision_plist"
  /usr/bin/plutil -convert json -o "$DECISION_MANIFEST_OUTPUT" "$decision_plist"
  rm -f "$decision_plist"
  echo "Decision: $decision"
  echo "Decision manifest: $DECISION_MANIFEST_OUTPUT"
fi