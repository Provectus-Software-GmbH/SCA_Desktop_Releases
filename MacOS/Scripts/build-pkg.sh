#!/bin/bash
set -euo pipefail

PACKAGE_ID="de.provectus.securecontacts.intune-bootstrap"
PACKAGE_VERSION="${PACKAGE_VERSION:-1.1.0}"
PROJECT_DIR=$(cd "$(dirname "$0")" && pwd)
SOURCE_SCRIPT="${1:-$PROJECT_DIR/Install-SecureContacts.sh}"
BUILD_DIR="$PROJECT_DIR/build"
STAGING_DIR=$(/usr/bin/mktemp -d /tmp/securecontacts-intune-build.XXXXXX)
PAYLOAD_DIR="$STAGING_DIR/payload"
SCRIPTS_DIR="$PROJECT_DIR"
INSTALL_DIR="$PAYLOAD_DIR/Library/Application Support/SecureContacts/IntuneBootstrap"
OUTPUT_PKG="$BUILD_DIR/SecureContacts-Intune-${PACKAGE_VERSION}.pkg"

cleanup() {
  /bin/rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

if [ ! -f "$SOURCE_SCRIPT" ]; then
  echo "Source installer not found: $SOURCE_SCRIPT" >&2
  exit 1
fi

if [ ! -f "$SCRIPTS_DIR/postinstall" ]; then
  echo "pkgbuild postinstall script not found: $SCRIPTS_DIR/postinstall" >&2
  exit 1
fi

/bin/bash -n "$SOURCE_SCRIPT"
/bin/bash -n "$SCRIPTS_DIR/postinstall"

/bin/mkdir -p "$BUILD_DIR"
/bin/mkdir -p "$INSTALL_DIR"
COPYFILE_DISABLE=1 /bin/cp "$SOURCE_SCRIPT" "$INSTALL_DIR/Install-SecureContacts.sh"
/bin/chmod 0755 "$INSTALL_DIR/Install-SecureContacts.sh"
/bin/chmod 0755 "$SCRIPTS_DIR/postinstall"
/usr/bin/xattr -cr "$PAYLOAD_DIR"

COPYFILE_DISABLE=1 /usr/bin/pkgbuild \
  --root "$PAYLOAD_DIR" \
  --scripts "$SCRIPTS_DIR" \
  --identifier "$PACKAGE_ID" \
  --version "$PACKAGE_VERSION" \
  --install-location / \
  "$OUTPUT_PKG"

echo "$OUTPUT_PKG"
