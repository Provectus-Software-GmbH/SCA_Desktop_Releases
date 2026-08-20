#!/bin/bash
set -euo pipefail

EXPECTED_BUNDLE_ID="de.provectus.SecureContactsDesktop"
EXPECTED_SIGNER="Developer ID Installer: Provectus Software GmbH (572S9T76X8)"
RECIPE="${RECIPE:-$(cd "$(dirname "$0")" && pwd)/de.provectus.securecontacts.intune.recipe.yaml}"
OUTPUT_PATH="./artifacts"

usage() {
  cat <<'EOF'
Usage: Invoke-SecureContactsAutoUpdate.sh [--output PATH] [--skip-recipe]

Stages and validates one Secure Contacts ARM64 PKG. This script never writes to
Microsoft Graph. Run it on macOS with AutoPkg 2.3+ and the Apple package tools.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --output)
      [ "$#" -ge 2 ] || { echo "--output requires a path" >&2; exit 2; }
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --skip-recipe)
      SKIP_RECIPE=true
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

SKIP_RECIPE="${SKIP_RECIPE:-false}"
mkdir -p "$OUTPUT_PATH"

command -v shasum >/dev/null || { echo "shasum is required" >&2; exit 1; }
command -v pkgutil >/dev/null || { echo "pkgutil is required" >&2; exit 1; }
command -v spctl >/dev/null || { echo "spctl is required" >&2; exit 1; }

if [ "$SKIP_RECIPE" != true ]; then
  command -v autopkg >/dev/null || { echo "autopkg is required unless --skip-recipe is used" >&2; exit 1; }
  autopkg run "$RECIPE" -k "OUTPUT_PATH=$OUTPUT_PATH"
fi

pkg_count=$(find "$OUTPUT_PATH" -maxdepth 1 -type f -name 'SecureContacts-*-arm64.pkg' -print | wc -l | tr -d ' ')
checksum_count=$(find "$OUTPUT_PATH" -maxdepth 1 -type f -name 'SecureContacts-*-arm64.pkg.sha256' -print | wc -l | tr -d ' ')
[ "$pkg_count" -eq 1 ] || { echo "Expected exactly one Secure Contacts ARM64 PKG, found $pkg_count" >&2; exit 1; }
[ "$checksum_count" -eq 1 ] || { echo "Expected exactly one matching SHA256 file, found $checksum_count" >&2; exit 1; }

pkg_path=$(find "$OUTPUT_PATH" -maxdepth 1 -type f -name 'SecureContacts-*-arm64.pkg' -print)
checksum_path=$(find "$OUTPUT_PATH" -maxdepth 1 -type f -name 'SecureContacts-*-arm64.pkg.sha256' -print)
pkg_name=$(basename "$pkg_path")
checksum_name=$(basename "$checksum_path")
expected_checksum_name="${pkg_name}.sha256"
[ "$checksum_name" = "$expected_checksum_name" ] || { echo "Checksum filename does not match package: $checksum_name" >&2; exit 1; }

candidate_version=$(printf '%s\n' "$pkg_name" | sed -n 's/^SecureContacts-\([0-9][0-9.]*\)-arm64\.pkg$/\1/p')
[ -n "$candidate_version" ] || { echo "Could not parse package version from $pkg_name" >&2; exit 1; }

(
  cd "$OUTPUT_PATH"
  shasum -a 256 -c "$checksum_name"
)

signature_output=$(pkgutil --check-signature "$pkg_path")
printf '%s\n' "$signature_output" | grep -F "$EXPECTED_SIGNER" >/dev/null || {
  echo "Unexpected package signer" >&2
  printf '%s\n' "$signature_output" >&2
  exit 1
}
printf '%s\n' "$signature_output" | grep -F 'Developer ID Certification Authority' >/dev/null || { echo "Expected Developer ID Certification Authority missing" >&2; exit 1; }
printf '%s\n' "$signature_output" | grep -F 'Apple Root CA' >/dev/null || { echo "Expected Apple Root CA missing" >&2; exit 1; }

spctl --assess --type install --verbose=4 "$pkg_path"

expanded_path=$(mktemp -d)
trap 'rm -rf "$expanded_path"' EXIT
pkgutil --expand-full "$pkg_path" "$expanded_path/package"

info_path=$(find "$expanded_path/package" -type f -path '*/Contents/Info.plist' -print | head -n 1)
[ -n "$info_path" ] || { echo "No application Info.plist found in package" >&2; exit 1; }

bundle_id=$(/usr/libexec/PlistBuddy -c 'Print:CFBundleIdentifier' "$info_path")
bundle_version=$(/usr/libexec/PlistBuddy -c 'Print:CFBundleShortVersionString' "$info_path")
executable_name=$(/usr/libexec/PlistBuddy -c 'Print:CFBundleExecutable' "$info_path")
[ "$bundle_id" = "$EXPECTED_BUNDLE_ID" ] || { echo "Unexpected bundle ID: $bundle_id" >&2; exit 1; }
[ "$bundle_version" = "$candidate_version" ] || { echo "Package version $candidate_version does not match bundle version $bundle_version" >&2; exit 1; }

app_root=$(dirname "$info_path")
executable_path="$app_root/MacOS/$executable_name"
[ -f "$executable_path" ] || { echo "Application executable not found: $executable_path" >&2; exit 1; }
file_output=$(file "$executable_path")
printf '%s\n' "$file_output" | grep -E 'arm64|Apple silicon' >/dev/null || {
  echo "Application executable is not identified as ARM64" >&2
  printf '%s\n' "$file_output" >&2
  exit 1
}

printf '\nValidation successful\n'
printf 'Package: %s\n' "$pkg_name"
printf 'Version: %s\n' "$candidate_version"
printf 'Bundle ID: %s\n' "$bundle_id"
printf 'SHA256: %s\n' "$(shasum -a 256 "$pkg_path" | awk '{print $1}')"
printf 'Signer: %s\n' "$EXPECTED_SIGNER"
printf 'Graph publishing: disabled (validation-only)\n'
