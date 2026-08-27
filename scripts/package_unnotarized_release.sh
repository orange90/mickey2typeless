#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE_DIR="$PROJECT_DIR/release"
WORK_DIR="$(mktemp -d -t mickey-unnotarized-release.XXXXXX)"
ARCHIVE_PATH="$WORK_DIR/MicKey.xcarchive"
PAYLOAD_DIR="$WORK_DIR/payload"
trap 'rm -rf "$WORK_DIR"' EXIT

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

mkdir -p "$RELEASE_DIR" "$PAYLOAD_DIR"
cd "$PROJECT_DIR"
xcodegen generate

VERSION="$(xcodebuild -project MicKey.xcodeproj -scheme MicKey -showBuildSettings CODE_SIGNING_ALLOWED=NO | awk '/MARKETING_VERSION/ { print $3; exit }')"
if [[ -z "$VERSION" ]]; then
  echo "Unable to determine MARKETING_VERSION" >&2
  exit 2
fi

DMG_NAME="MicKey-$VERSION-unnotarized.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"
CHECKSUM_PATH="$DMG_PATH.sha256"

xcodebuild archive \
  -project MicKey.xcodeproj \
  -scheme MicKey \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO

APP_PATH="$PAYLOAD_DIR/MicKey.app"
ditto "$ARCHIVE_PATH/Products/Applications/MicKey.app" "$APP_PATH"
codesign \
  --force \
  --deep \
  --sign - \
  --options runtime \
  --entitlements "$PROJECT_DIR/MicKey/Resources/MicKey.entitlements" \
  "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

ARCHITECTURES="$(lipo -archs "$APP_PATH/Contents/MacOS/MicKey")"
if [[ "$ARCHITECTURES" != *arm64* || "$ARCHITECTURES" != *x86_64* ]]; then
  echo "Expected a Universal 2 binary, found: $ARCHITECTURES" >&2
  exit 2
fi

ln -s /Applications "$PAYLOAD_DIR/Applications"
hdiutil create \
  -volname "MicKey $VERSION" \
  -srcfolder "$PAYLOAD_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH"
hdiutil verify "$DMG_PATH"
(cd "$RELEASE_DIR" && shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256")

echo "Unnotarized release ready: $DMG_PATH"
echo "Checksum ready: $CHECKSUM_PATH"
echo "Gatekeeper will require users to choose Open Anyway in Privacy & Security."
