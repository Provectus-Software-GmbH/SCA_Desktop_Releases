#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALIDATOR="$SCRIPT_DIR/Validate-SecureContactsPackage.sh"
OUTPUT_PATH="./artifacts"
MANIFEST_OUTPUT=""
DECISION_MANIFEST_OUTPUT=""
INTUNE_APP_ID="${INTUNE_APP_ID:-}"
GRAPH_ACCESS_TOKEN="${GRAPH_ACCESS_TOKEN:-}"
INTUNE_TENANT_ID="${INTUNE_TENANT_ID:-}"
INTUNE_CLIENT_ID="${INTUNE_CLIENT_ID:-}"
INTUNE_CERTIFICATE_PATH="${INTUNE_CERTIFICATE_PATH:-}"
INTUNE_CERTIFICATE_PASSWORD_FILE="${INTUNE_CERTIFICATE_PASSWORD_FILE:-}"
INTUNE_AUTH_METHOD="${INTUNE_AUTH_METHOD:-auto}"
SKIP_RECIPE=false
PUBLISH=false
WHAT_IF=false
CLEANUP=false
CLEANUP_APPLY=false
POLL_ATTEMPTS="${INTUNE_POLL_ATTEMPTS:-10}"

usage() {
  cat <<'EOF'
Usage: Sync-SecureContactsToIntune.sh [--output PATH] [--manifest-output PATH]
  [--decision-manifest-output PATH] [--app-id GUID]
  [--auth-method auto|certificate|token]
  [--skip-recipe] [--publish] [--what-if] [--cleanup [--apply]]

Stages and validates one Secure Contacts ARM64 PKG. Validation is the default.
--what-if performs a read-only Microsoft Graph beta lookup and version decision.
--publish updates the explicitly selected existing macOS PKG app only.
--cleanup lists abandoned uncommitted content versions from the selected app.
--cleanup --apply deletes the listed abandoned uncommitted content versions.

Graph authentication is certificate-based by default when certificate settings are
provided: INTUNE_TENANT_ID, INTUNE_CLIENT_ID, and INTUNE_CERTIFICATE_PATH.
For a password-protected PFX/P12 or PEM, provide the protected password file with
INTUNE_CERTIFICATE_PASSWORD_FILE; the password is never accepted as a command argument.
GRAPH_ACCESS_TOKEN is supported for short-lived testing; set INTUNE_AUTH_METHOD=token.
EOF
}

status() {
  printf '[Secure Contacts] %s\n' "$1"
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
    --auth-method)
      [ "$#" -ge 2 ] || { echo "--auth-method requires auto, certificate, or token" >&2; exit 2; }
      INTUNE_AUTH_METHOD="$2"
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
    --cleanup)
      CLEANUP=true
      shift
      ;;
    --apply)
      CLEANUP_APPLY=true
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

if [ "$CLEANUP" = true ] && [ "$PUBLISH" = true ]; then
  echo "--cleanup cannot be combined with --publish" >&2
  exit 2
fi

if [ "$CLEANUP_APPLY" = true ] && [ "$CLEANUP" != true ]; then
  echo "--apply requires --cleanup" >&2
  exit 2
fi

if [ "$CLEANUP_APPLY" = true ] && [ "$WHAT_IF" = true ]; then
  echo "--cleanup --apply cannot be combined with --what-if" >&2
  exit 2
fi

if ! printf '%s\n' "$POLL_ATTEMPTS" | grep -Eq '^[1-9][0-9]*$'; then
  echo "INTUNE_POLL_ATTEMPTS must be a positive integer" >&2
  exit 2
fi

if [ -z "$MANIFEST_OUTPUT" ]; then
  MANIFEST_OUTPUT="$OUTPUT_PATH/validation-manifest.json"
fi

if [ -z "$DECISION_MANIFEST_OUTPUT" ]; then
  DECISION_MANIFEST_OUTPUT="$OUTPUT_PATH/decision-manifest.json"
fi

mkdir -p "$OUTPUT_PATH"
if [ "$CLEANUP" != true ]; then
  validator_arguments=(--output "$OUTPUT_PATH" --manifest-output "$MANIFEST_OUTPUT")
  if [ "$SKIP_RECIPE" = true ]; then
    validator_arguments+=(--skip-recipe)
  fi

  status "Validating macOS PKG"
  "$VALIDATOR" "${validator_arguments[@]}"
fi

if [ "$PUBLISH" = true ] || [ "$CLEANUP" = true ]; then
  [ -n "$INTUNE_APP_ID" ] || { echo "--app-id or INTUNE_APP_ID is required for Graph operation" >&2; exit 2; }
  printf '%s' "$INTUNE_APP_ID" | grep -Eq '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$' || {
    echo "Invalid Intune macOS app ID" >&2
    exit 2
  }

  command -v curl >/dev/null || { echo "curl is required for Graph publishing" >&2; exit 1; }
  command -v jq >/dev/null || { echo "jq is required for Graph publishing; install it with 'brew install jq'" >&2; exit 1; }
  if [ "$CLEANUP" != true ]; then
    command -v openssl >/dev/null || { echo "openssl is required for Graph publishing" >&2; exit 1; }
    command -v xxd >/dev/null || { echo "xxd is required for Graph publishing" >&2; exit 1; }
    command -v dd >/dev/null || { echo "dd is required for Graph publishing" >&2; exit 1; }
    [ -f "$MANIFEST_OUTPUT" ] || { echo "Validation manifest was not created: $MANIFEST_OUTPUT" >&2; exit 1; }
  fi

  graph_response=$(mktemp)
  graph_header=$(mktemp)
  azure_config_dir=""
  azure_certificate_path=""
  encryption_file=$(mktemp)
  ciphertext_file=$(mktemp)
  encryption_key_file=$(mktemp)
  mac_key_file=$(mktemp)
  iv_file=$(mktemp)
  upload_dir=$(mktemp -d)
  cleanup_publish_files() {
    rm -f "$graph_response" "$graph_header" "$encryption_file" "$ciphertext_file" "$encryption_key_file" "$mac_key_file" "$iv_file"
    rm -rf "$upload_dir"
    [ -z "$azure_certificate_path" ] || rm -f "$azure_certificate_path"
    [ -z "$azure_config_dir" ] || rm -rf "$azure_config_dir"
  }
  trap cleanup_publish_files EXIT
  chmod 600 "$graph_header" "$encryption_key_file" "$mac_key_file"

  case "$INTUNE_AUTH_METHOD" in
    auto)
      if [ -n "$GRAPH_ACCESS_TOKEN" ] && [ -z "$INTUNE_TENANT_ID$INTUNE_CLIENT_ID$INTUNE_CERTIFICATE_PATH" ]; then
        INTUNE_AUTH_METHOD=token
      else
        INTUNE_AUTH_METHOD=certificate
      fi
      ;;
    certificate|token) ;;
    *) echo "INTUNE_AUTH_METHOD must be auto, certificate, or token" >&2; exit 2 ;;
  esac

  if [ "$INTUNE_AUTH_METHOD" = certificate ]; then
    [ -n "$INTUNE_TENANT_ID" ] || { echo "INTUNE_TENANT_ID is required for certificate authentication" >&2; exit 2; }
    [ -n "$INTUNE_CLIENT_ID" ] || { echo "INTUNE_CLIENT_ID is required for certificate authentication" >&2; exit 2; }
    [ -n "$INTUNE_CERTIFICATE_PATH" ] || { echo "INTUNE_CERTIFICATE_PATH is required for certificate authentication" >&2; exit 2; }
    [ -f "$INTUNE_CERTIFICATE_PATH" ] || { echo "Certificate file was not found: $INTUNE_CERTIFICATE_PATH" >&2; exit 2; }
    if [ -n "$INTUNE_CERTIFICATE_PASSWORD_FILE" ]; then
      [ -f "$INTUNE_CERTIFICATE_PASSWORD_FILE" ] || { echo "Certificate password file was not found: $INTUNE_CERTIFICATE_PASSWORD_FILE" >&2; exit 2; }
      [ -r "$INTUNE_CERTIFICATE_PASSWORD_FILE" ] || { echo "Certificate password file is not readable: $INTUNE_CERTIFICATE_PASSWORD_FILE" >&2; exit 2; }
      command -v openssl >/dev/null || { echo "openssl is required for password-protected certificate authentication" >&2; exit 1; }
      azure_certificate_path=$(mktemp)
      chmod 600 "$azure_certificate_path"
      certificate_extension="${INTUNE_CERTIFICATE_PATH##*.}"
      certificate_extension=$(printf '%s' "$certificate_extension" | tr '[:upper:]' '[:lower:]')
      if [ "$certificate_extension" = pfx ] || [ "$certificate_extension" = p12 ]; then
        openssl pkcs12 -in "$INTUNE_CERTIFICATE_PATH" -passin "file:$INTUNE_CERTIFICATE_PASSWORD_FILE" -nodes -out "$azure_certificate_path" || {
          echo "Unable to unlock the password-protected PFX/P12 certificate" >&2
          exit 1
        }
      else
        openssl pkey -in "$INTUNE_CERTIFICATE_PATH" -passin "file:$INTUNE_CERTIFICATE_PASSWORD_FILE" -out "$azure_certificate_path" || {
          echo "Unable to unlock the password-protected PEM private key" >&2
          exit 1
        }
        openssl x509 -in "$INTUNE_CERTIFICATE_PATH" -outform PEM >> "$azure_certificate_path" || {
          echo "Unable to read the certificate from the password-protected PEM" >&2
          exit 1
        }
      fi
      INTUNE_CERTIFICATE_PATH="$azure_certificate_path"
    fi
    command -v az >/dev/null || { echo "Azure CLI (az) is required for certificate authentication" >&2; exit 1; }
    azure_config_dir=$(mktemp -d)
    chmod 700 "$azure_config_dir"
    export AZURE_CONFIG_DIR="$azure_config_dir"
    status "Authenticating to Microsoft Graph with Azure CLI certificate credentials"
    az login --service-principal --username "$INTUNE_CLIENT_ID" --tenant "$INTUNE_TENANT_ID" \
      --certificate "$INTUNE_CERTIFICATE_PATH" --allow-no-subscriptions --output none
  elif [ -z "$GRAPH_ACCESS_TOKEN" ]; then
    echo "GRAPH_ACCESS_TOKEN is required when INTUNE_AUTH_METHOD=token" >&2
    exit 2
  fi

  refresh_graph_token() {
    if [ "$INTUNE_AUTH_METHOD" = certificate ]; then
      GRAPH_ACCESS_TOKEN=$(az account get-access-token --resource-type ms-graph --query accessToken --output tsv) || {
        echo "Unable to acquire a Microsoft Graph access token with Azure CLI" >&2
        return 1
      }
      [ -n "$GRAPH_ACCESS_TOKEN" ] || { echo "Azure CLI returned an empty Microsoft Graph access token" >&2; return 1; }
    fi
    printf 'Authorization: Bearer %s\nAccept: application/json\n' "$GRAPH_ACCESS_TOKEN" > "$graph_header"
    chmod 600 "$graph_header"
  }

  graph_request() {
    local method="$1" url="$2" body="$3" output="$4" status
    refresh_graph_token
    if [ -n "$body" ]; then
      status=$(curl --silent --show-error --request "$method" --url "$url" \
        --connect-timeout 15 --max-time 60 \
        --header "@$graph_header" --header 'Content-Type: application/json' \
        --data-binary "@$body" --output "$output" --write-out '%{http_code}') || {
        echo "Graph request failed: $method" >&2
        return 1
      }
    else
      status=$(curl --silent --show-error --request "$method" --url "$url" \
        --connect-timeout 15 --max-time 60 \
        --header "@$graph_header" --output "$output" --write-out '%{http_code}') || {
        echo "Graph request failed: $method" >&2
        return 1
      }
    fi
    case "$status" in
      2??) return 0 ;;
      *) echo "Graph request returned HTTP $status: $method" >&2; return 1 ;;
    esac
  }

  graph_url="https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$INTUNE_APP_ID"
  status "Reading existing Intune macOS PKG app"
  graph_request GET "$graph_url" "" "$graph_response"
  jq -e . "$graph_response" >/dev/null
  graph_type=$(jq -r '."@odata.type" // empty' "$graph_response")
  [ "$graph_type" = '#microsoft.graph.macOSPkgApp' ] || { echo "Target app is not a macOSPkgApp" >&2; exit 1; }
  content_url="$graph_url/microsoft.graph.macOSPkgApp"

  if [ "$CLEANUP" = true ]; then
    committed_content_version=$(jq -r '.committedContentVersion // empty' "$graph_response")
    status "Listing abandoned uncommitted content versions"
    cleanup_candidates=$(mktemp)
    cleanup_page_url="$content_url/contentVersions"
    while [ -n "$cleanup_page_url" ]; do
      graph_request GET "$cleanup_page_url" "" "$graph_response"
      jq -r --arg committed "$committed_content_version" \
        '.value[]? | select((.isCommitted // null) == false and (.id // "") != $committed) | [.id, (.createdDateTime // "unknown")] | @tsv' \
        "$graph_response" >> "$cleanup_candidates"
      cleanup_page_url=$(jq -r '."@odata.nextLink" // empty' "$graph_response")
    done
    cleanup_count=0
    while IFS=$'\t' read -r content_version_id created_date; do
      [ -n "$content_version_id" ] || continue
      if [ "$CLEANUP_APPLY" = true ]; then
        status "Deleting abandoned content version $content_version_id"
        graph_request DELETE "$content_url/contentVersions/$content_version_id" "" "$graph_response"
        cleanup_count=$((cleanup_count + 1))
      else
        printf 'Cleanup candidate: %s (created: %s)\n' "$content_version_id" "$created_date"
      fi
    done < "$cleanup_candidates"
    if [ "$CLEANUP_APPLY" = true ]; then
      echo "Cleanup complete: removed $cleanup_count abandoned uncommitted content version(s)"
    else
      candidate_count=$(wc -l < "$cleanup_candidates" | tr -d ' ')
      echo "Cleanup preview complete: $candidate_count abandoned uncommitted content version(s) eligible for deletion"
      echo "Re-run with --cleanup --apply to delete these versions"
    fi
    rm -f "$cleanup_candidates"
    exit 0
  fi

  if [ "$WHAT_IF" = true ]; then
    candidate_bundle_id=$(/usr/bin/plutil -extract BundleId raw -o - "$MANIFEST_OUTPUT")
    candidate_version=$(/usr/bin/plutil -extract ReleaseVersion raw -o - "$MANIFEST_OUTPUT")
    matching_count=$(jq '[.includedApps[]? | select(.bundleId == $bundle_id)] | length' --arg bundle_id "$candidate_bundle_id" "$graph_response")
    intune_version=$(jq -r --arg bundle_id "$candidate_bundle_id" '.includedApps[] | select(.bundleId == $bundle_id) | .bundleVersion' "$graph_response")
    [ "$candidate_bundle_id" = 'de.provectus.SecureContactsDesktop' ] || { echo "Unexpected candidate bundle ID" >&2; exit 1; }
    [ "$matching_count" -eq 1 ] || { echo "Expected exactly one matching includedApps entry, found $matching_count" >&2; exit 1; }
    printf '%s\n' "$intune_version" | grep -Eq '^[0-9]+(\.[0-9]+)*$' || { echo "Invalid Intune bundle version" >&2; exit 1; }
    printf '%s\n' "$candidate_version" | grep -Eq '^[0-9]+(\.[0-9]+)*$' || { echo "Invalid candidate version" >&2; exit 1; }
    version_compare() {
      awk -v left="$1" -v right="$2" 'BEGIN { lc=split(left,l,"."); rc=split(right,r,"."); c=lc>rc?lc:rc; for(i=1;i<=c;i++){lv=(i<=lc?l[i]:0)+0;rv=(i<=rc?r[i]:0)+0;if(lv<rv){print -1;exit}if(lv>rv){print 1;exit}}print 0}'
    }
    version_order=$(version_compare "$candidate_version" "$intune_version")
    if [ "$version_order" -lt 0 ]; then
      echo "Candidate version $candidate_version is older than Intune version $intune_version" >&2
      exit 1
    elif [ "$version_order" -eq 0 ]; then
      decision="NoUpdateRequired"
    else
      decision="UpdateExistingApp"
    fi
    status "What-if decision: $decision (Intune $intune_version, candidate $candidate_version)"
    decision_plist=$(mktemp)
    /usr/bin/plutil -create xml1 "$decision_plist"
    /usr/bin/plutil -insert Decision -string "$decision" "$decision_plist"
    /usr/bin/plutil -insert IntuneAppId -string "$INTUNE_APP_ID" "$decision_plist"
    /usr/bin/plutil -insert GraphEndpoint -string "$graph_url" "$decision_plist"
    /usr/bin/plutil -insert ResourceType -string "$graph_type" "$decision_plist"
    /usr/bin/plutil -insert CandidateVersion -string "$candidate_version" "$decision_plist"
    /usr/bin/plutil -insert IntuneBundleVersion -string "$intune_version" "$decision_plist"
    /usr/bin/plutil -insert BundleId -string "$candidate_bundle_id" "$decision_plist"
    /usr/bin/plutil -insert CreatedUtc -string "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$decision_plist"
    /usr/bin/plutil -convert json -o "$DECISION_MANIFEST_OUTPUT" "$decision_plist"
    rm -f "$decision_plist"
    echo "Decision: $decision"
    echo "Decision manifest: $DECISION_MANIFEST_OUTPUT"
    exit 0
  fi

  candidate_bundle_id=$(/usr/bin/plutil -extract BundleId raw -o - "$MANIFEST_OUTPUT")
  candidate_version=$(/usr/bin/plutil -extract ReleaseVersion raw -o - "$MANIFEST_OUTPUT")
  package_path=$(/usr/bin/plutil -extract PackagePath raw -o - "$MANIFEST_OUTPUT")
  package_name=$(/usr/bin/plutil -extract PackageName raw -o - "$MANIFEST_OUTPUT")
  package_sha256=$(/usr/bin/plutil -extract Sha256 raw -o - "$MANIFEST_OUTPUT" | tr '[:upper:]' '[:lower:]')
  [ "$candidate_bundle_id" = 'de.provectus.SecureContactsDesktop' ] || { echo "Unexpected candidate bundle ID" >&2; exit 1; }
  [ -f "$package_path" ] || { echo "Validated package is missing" >&2; exit 1; }
  [ "$(basename "$package_path")" = "$package_name" ] || { echo "Validation manifest package name mismatch" >&2; exit 1; }
  printf '%s\n' "$package_sha256" | grep -Eq '^[0-9a-f]{64}$' || { echo "Invalid package SHA256 in validation manifest" >&2; exit 1; }
  [ "$(shasum -a 256 "$package_path" | awk '{print tolower($1)}')" = "$package_sha256" ] || { echo "Package SHA256 no longer matches validation manifest" >&2; exit 1; }

  matching_count=$(jq '[.includedApps[]? | select(.bundleId == "de.provectus.SecureContactsDesktop")] | length' "$graph_response")
  [ "$matching_count" -eq 1 ] || { echo "Expected exactly one Secure Contacts includedApps entry, found $matching_count" >&2; exit 1; }
  intune_version=$(jq -r '.includedApps[] | select(.bundleId == "de.provectus.SecureContactsDesktop") | .bundleVersion' "$graph_response")
  intune_primary_version=$(jq -r '.primaryBundleVersion // empty' "$graph_response")
  intune_file_name=$(jq -r '.fileName // empty' "$graph_response")
  printf '%s\n' "$intune_version" | grep -Eq '^[0-9]+(\.[0-9]+)*$' || { echo "Invalid Intune bundle version" >&2; exit 1; }
  printf '%s\n' "$candidate_version" | grep -Eq '^[0-9]+(\.[0-9]+)*$' || { echo "Invalid candidate version" >&2; exit 1; }
  version_compare() {
    awk -v left="$1" -v right="$2" 'BEGIN { lc=split(left,l,"."); rc=split(right,r,"."); c=lc>rc?lc:rc; for(i=1;i<=c;i++){lv=(i<=lc?l[i]:0)+0;rv=(i<=rc?r[i]:0)+0;if(lv<rv){print -1;exit}if(lv>rv){print 1;exit}}print 0}'
  }
  version_order=$(version_compare "$candidate_version" "$intune_version")
  [ "$version_order" -ge 0 ] || { echo "Candidate version $candidate_version is older than Intune version $intune_version" >&2; exit 1; }
  if [ "$version_order" -eq 0 ] && [ "$intune_primary_version" = "$candidate_version" ] && [ "$intune_file_name" = "$package_name" ]; then
    echo "No update required: version $candidate_version is already present"
    exit 0
  fi
  status "Updating Intune app metadata to version $candidate_version (included: $intune_version; primary: ${intune_primary_version:-missing}; file: ${intune_file_name:-missing})"

  original_identity=$(jq -c '{id,displayName,publisher,productCode,primaryBundleId}' "$graph_response")
  existing_included_apps=$(jq -c '.includedApps // []' "$graph_response")
  status "Creating Intune content version"
  content_version_body=$(mktemp); printf '{}\n' > "$content_version_body"
  graph_request POST "$content_url/contentVersions" "$content_version_body" "$graph_response"; rm -f "$content_version_body"
  content_version_id=$(jq -r '.id // empty' "$graph_response")
  [ -n "$content_version_id" ] || { echo "Graph did not return a content version ID" >&2; exit 1; }

  status "Encrypting $package_name"
  openssl rand 32 > "$encryption_key_file"
  openssl rand 32 > "$mac_key_file"
  openssl rand 16 > "$iv_file"
  openssl enc -aes-256-cbc -K "$(xxd -p -c 256 "$encryption_key_file")" -iv "$(xxd -p -c 256 "$iv_file")" -in "$package_path" -out "$ciphertext_file"
  printf '\000%.0s' {1..32} > "$encryption_file"
  cat "$iv_file" "$ciphertext_file" >> "$encryption_file"
  mac_raw="$upload_dir/mac.raw"
  tail -c +33 "$encryption_file" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$(xxd -p -c 256 "$mac_key_file")" -binary > "$mac_raw"
  dd if="$mac_raw" of="$encryption_file" bs=32 count=1 conv=notrunc 2>/dev/null
  encryption_key=$(openssl base64 -A -in "$encryption_key_file")
  mac_key=$(openssl base64 -A -in "$mac_key_file")
  initialization_vector=$(openssl base64 -A -in "$iv_file")
  mac=$(openssl base64 -A -in "$mac_raw")
  package_size=$(wc -c < "$package_path" | tr -d ' ')
  encrypted_size=$(wc -c < "$encryption_file" | tr -d ' ')
  status "Registering encrypted content file"
  file_body=$(mktemp)
  jq -n --arg name "$package_name" --argjson size "$package_size" --argjson encrypted "$encrypted_size" '{"@odata.type":"#microsoft.graph.mobileAppContentFile",name:$name,size:$size,sizeEncrypted:$encrypted,manifest:null,isDependency:false}' > "$file_body"
  graph_request POST "$content_url/contentVersions/$content_version_id/files" "$file_body" "$graph_response"; rm -f "$file_body"
  file_id=$(jq -r '.id // empty' "$graph_response")
  [ -n "$file_id" ] || { echo "Graph did not return a content file ID" >&2; exit 1; }

  for attempt in $(seq 1 "$POLL_ATTEMPTS"); do
    graph_request GET "$content_url/contentVersions/$content_version_id/files/$file_id" "" "$graph_response"
    file_state=$(jq -r '.uploadState // empty' "$graph_response" | tr '[:upper:]' '[:lower:]')
    printf 'Waiting for Azure storage URI (attempt %s/%s; state: %s)\n' "$attempt" "$POLL_ATTEMPTS" "${file_state:-missing}"
    case "$file_state" in
      azurestorageurisuccess|azurestorageurisuccessful|azurestorageurirequestsuccess) break ;;
      azurestorageurifailure|azurestorageurifailed) echo "Azure storage URI request failed" >&2; exit 1 ;;
    esac
    [ "$attempt" -lt "$POLL_ATTEMPTS" ] || { echo "Timed out waiting for Azure storage URI (last state: ${file_state:-missing})" >&2; exit 1; }
    sleep 5
  done
  case "$file_state" in
    azurestorageurisuccess|azurestorageurisuccessful|azurestorageurirequestsuccess) ;;
    *) echo "Timed out waiting for Azure storage URI (last state: ${file_state:-missing})" >&2; exit 1 ;;
  esac
  sas_url=$(jq -r '.azureStorageUri // empty' "$graph_response")
  [ -n "$sas_url" ] || { echo "Graph did not return an Azure storage URI" >&2; exit 1; }

  block_size=4194304
  block_count=$(( (encrypted_size + block_size - 1) / block_size ))
  status "Uploading $block_count Azure block(s)"
  for ((block=0; block<block_count; block++)); do
    printf '[Secure Contacts] Uploading Azure block %s/%s\n' "$((block + 1))" "$block_count"
    chunk="$upload_dir/block-$block"
    dd if="$encryption_file" of="$chunk" bs="$block_size" skip="$block" count=1 2>/dev/null
    block_id=$(printf '%04d' "$block" | openssl base64 -A)
    upload_status=$(curl --silent --show-error --request PUT \
      --url "$sas_url&comp=block&blockid=$block_id" \
      --connect-timeout 15 --max-time 300 \
      --header 'x-ms-blob-type: BlockBlob' --header 'Content-Type: application/octet-stream' \
      --data-binary "@$chunk" --output /dev/null --write-out '%{http_code}') || {
      echo "Azure block upload failed" >&2
      exit 1
    }
    case "$upload_status" in 201|202) ;; *) echo "Azure block upload returned HTTP $upload_status" >&2; exit 1 ;; esac
    printf '[Secure Contacts] Uploaded Azure block %s/%s (HTTP %s)\n' "$((block + 1))" "$block_count" "$upload_status"
  done
  block_list="$upload_dir/blocklist.xml"
  status "Finalizing Azure block upload"
  { printf '<?xml version="1.0" encoding="utf-8"?><BlockList>'; for ((block=0; block<block_count; block++)); do printf '<Latest>%s</Latest>' "$(printf '%04d' "$block" | openssl base64 -A)"; done; printf '</BlockList>'; } > "$block_list"
  upload_status=$(curl --silent --show-error --request PUT \
    --url "$sas_url&comp=blocklist" --header 'Content-Type: application/xml' \
    --connect-timeout 15 --max-time 60 \
    --data-binary "@$block_list" --output /dev/null --write-out '%{http_code}') || {
    echo "Azure block finalization failed" >&2
    exit 1
  }
  case "$upload_status" in 201|202) ;; *) echo "Azure block finalization returned HTTP $upload_status" >&2; exit 1 ;; esac

  encryption_body=$(mktemp)
  status "Committing content file to Intune"
  file_digest=$(openssl dgst -sha256 -binary "$package_path" | openssl base64 -A)
  jq -n --arg encryptionKey "$encryption_key" --arg macKey "$mac_key" --arg initializationVector "$initialization_vector" --arg mac "$mac" --arg digest "$file_digest" \
    '{fileEncryptionInfo:{encryptionKey:$encryptionKey,macKey:$macKey,initializationVector:$initializationVector,mac:$mac,profileIdentifier:"ProfileVersion1",fileDigest:$digest,fileDigestAlgorithm:"SHA256"}}' > "$encryption_body"
  graph_request POST "$content_url/contentVersions/$content_version_id/files/$file_id/commit" "$encryption_body" "$graph_response"; rm -f "$encryption_body"
  commit_success=false
  for attempt in $(seq 1 "$POLL_ATTEMPTS"); do
    graph_request GET "$content_url/contentVersions/$content_version_id/files/$file_id" "" "$graph_response"
    file_state=$(jq -r '.uploadState // empty' "$graph_response" | tr '[:upper:]' '[:lower:]')
    printf 'Waiting for file commit (attempt %s/%s; state: %s)\n' "$attempt" "$POLL_ATTEMPTS" "${file_state:-missing}"
    case "$file_state" in
      commitfilesuccess|commitfilecompleted) commit_success=true; break ;;
      commitfilefailure|commitfilefailed) echo "Graph file commit failed" >&2; exit 1 ;;
    esac
    [ "$attempt" -lt "$POLL_ATTEMPTS" ] || { echo "Timed out waiting for file commit (last state: ${file_state:-missing})" >&2; exit 1; }
    sleep 5
  done
  [ "$commit_success" = true ] || { echo "Timed out waiting for file commit" >&2; exit 1; }
  status "Updating app metadata and committing content version $content_version_id"
  updated_included_apps=$(jq '[.[] | if .bundleId == "de.provectus.SecureContactsDesktop" then .bundleVersion = $version else . end]' \
    --arg version "$candidate_version" <<< "$existing_included_apps")
  patch_body=$(mktemp)
  jq -n --arg id "$content_version_id" --arg version "$candidate_version" --arg name "$package_name" --argjson includedApps "$updated_included_apps" \
    '{"@odata.type":"#microsoft.graph.macOSPkgApp",committedContentVersion:$id,fileName:$name,primaryBundleVersion:$version,includedApps:$includedApps}' > "$patch_body"
  graph_request PATCH "$graph_url" "$patch_body" "$graph_response"; rm -f "$patch_body"
  published=false
  for attempt in $(seq 1 "$POLL_ATTEMPTS"); do
    graph_request GET "$graph_url" "" "$graph_response"
    publishing_state=$(jq -r '.publishingState // empty' "$graph_response")
    upload_state=$(jq -r '.uploadState // empty' "$graph_response")
    included_version=$(jq -r '.includedApps[]? | select(.bundleId == "de.provectus.SecureContactsDesktop") | .bundleVersion // empty' "$graph_response")
    printf 'Waiting for app publishing (attempt %s/%s; publishingState: %s; uploadState: %s; includedVersion: %s)\n' \
      "$attempt" "$POLL_ATTEMPTS" "${publishing_state:-missing}" "${upload_state:-missing}" "${included_version:-missing}"
    if [ "$publishing_state" = published ] && [ "$upload_state" = 1 -o "$upload_state" = "1" ] && [ "$included_version" = "$candidate_version" ]; then
      published=true
      break
    fi
    [ "$attempt" -lt "$POLL_ATTEMPTS" ] || {
      echo "Timed out waiting for app metadata (publishingState: ${publishing_state:-missing}; uploadState: ${upload_state:-missing}; includedVersion: ${included_version:-missing})" >&2
      exit 1
    }
    sleep 5
  done
  [ "$published" = true ] || { echo "Timed out waiting for app publishing" >&2; exit 1; }
  status "Verifying published app identity and version"
  final_identity=$(jq -c '{id,displayName,publisher,productCode,primaryBundleId}' "$graph_response")
  [ "$original_identity" = "$final_identity" ] || { echo "App identity changed unexpectedly" >&2; exit 1; }
  [ "$(jq -r '.committedContentVersion // empty' "$graph_response")" = "$content_version_id" ] || { echo "Committed content version verification failed" >&2; exit 1; }
  [ "$(jq -r '.fileName // empty' "$graph_response")" = "$package_name" ] || { echo "Package file name verification failed" >&2; exit 1; }
  [ "$(jq -r '.primaryBundleVersion // empty' "$graph_response")" = "$candidate_version" ] || { echo "Primary bundle version verification failed" >&2; exit 1; }
  [ "$(jq -r '.includedApps[] | select(.bundleId == "de.provectus.SecureContactsDesktop") | .bundleVersion' "$graph_response")" = "$candidate_version" ] || { echo "Included app version verification failed" >&2; exit 1; }
  echo "Published existing macOS PKG app: version $candidate_version"
  exit 0
fi
