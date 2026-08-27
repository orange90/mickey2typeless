#!/bin/bash
set -euo pipefail

if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
  echo "DEVELOPMENT_TEAM is required" >&2
  exit 2
fi
if [[ -z "${NOTARY_PROFILE:-}" ]]; then
  echo "NOTARY_PROFILE is required" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE_DIR="$PROJECT_DIR/release"
ARCHIVE_PATH="$RELEASE_DIR/MicKey.xcarchive"
STAGING_DIR="$(mktemp -d -t mickey-release.XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT

mkdir -p "$RELEASE_DIR"
cd "$PROJECT_DIR"
xcodegen generate

VERSION="$(xcodebuild -project MicKey.xcodeproj -scheme MicKey -showBuildSettings | awk '/MARKETING_VERSION/ { print $3; exit }')"
if [[ -z "$VERSION" ]]; then
  echo "Unable to determine MARKETING_VERSION" >&2
  exit 2
fi
DMG_NAME="MicKey-$VERSION.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"
CHECKSUM_PATH="$DMG_PATH.sha256"

xcodebuild archive \
  -project MicKey.xcodeproj \
  -scheme MicKey \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  CODE_SIGN_STYLE=Manual \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO

ditto "$ARCHIVE_PATH/Products/Applications/MicKey.app" "$STAGING_DIR/MicKey.app"
codesign --verify --deep --strict --verbose=2 "$STAGING_DIR/MicKey.app"
lipo -archs "$STAGING_DIR/MicKey.app/Contents/MacOS/MicKey"

hdiutil create \
  -volname MicKey \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
(cd "$RELEASE_DIR" && shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256")

echo "Release ready: $DMG_PATH"
echo "Checksum ready: $CHECKSUM_PATH"
