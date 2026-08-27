#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ZH_FILE="$PROJECT_DIR/MicKey/Resources/zh-Hans.lproj/Localizable.strings"
EN_FILE="$PROJECT_DIR/MicKey/Resources/en.lproj/Localizable.strings"
ZH_INFO="$PROJECT_DIR/MicKey/Resources/zh-Hans.lproj/InfoPlist.strings"
EN_INFO="$PROJECT_DIR/MicKey/Resources/en.lproj/InfoPlist.strings"
TEMP_DIR="$(mktemp -d -t mickey-localizations.XXXXXX)"
trap 'rm -rf "$TEMP_DIR"' EXIT

extract_keys() {
  sed -n 's/^[[:space:]]*"\([^"]*\)"[[:space:]]*=.*/\1/p' "$1" | LC_ALL=C sort
}

plutil -lint "$ZH_FILE" "$EN_FILE" "$ZH_INFO" "$EN_INFO"
extract_keys "$ZH_FILE" > "$TEMP_DIR/zh-keys"
extract_keys "$EN_FILE" > "$TEMP_DIR/en-keys"
extract_keys "$ZH_INFO" > "$TEMP_DIR/zh-info-keys"
extract_keys "$EN_INFO" > "$TEMP_DIR/en-info-keys"

if ! diff -u "$TEMP_DIR/zh-keys" "$TEMP_DIR/en-keys"; then
  echo "Chinese and English localization keys do not match." >&2
  exit 1
fi

if ! diff -u "$TEMP_DIR/zh-info-keys" "$TEMP_DIR/en-info-keys"; then
  echo "Chinese and English Info.plist localization keys do not match." >&2
  exit 1
fi

for file in "$ZH_FILE" "$EN_FILE" "$ZH_INFO" "$EN_INFO"; do
  duplicates="$(extract_keys "$file" | uniq -d)"
  if [[ -n "$duplicates" ]]; then
    echo "Duplicate localization keys in $file:" >&2
    echo "$duplicates" >&2
    exit 1
  fi
done

echo "Localization files are valid and contain matching keys."
