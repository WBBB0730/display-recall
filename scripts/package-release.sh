#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Display Recall"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
ARTIFACT_DIR="$ROOT_DIR/dist/release"
ZIP_PATH="$ARTIFACT_DIR/Display-Recall-0.1.0.zip"

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
}

require_env DEVELOPER_ID_APPLICATION
require_env APPLE_ID
require_env APPLE_TEAM_ID
require_env APPLE_APP_SPECIFIC_PASSWORD
require_env SPARKLE_PUBLIC_ED_KEY

"$ROOT_DIR/scripts/package-app.sh" release

EXECUTABLE_PATH="$APP_DIR/Contents/MacOS/DisplayRecall"
if ! lipo -archs "$EXECUTABLE_PATH" | grep -q "arm64"; then
  echo "Release executable is missing arm64 architecture." >&2
  exit 1
fi
if ! lipo -archs "$EXECUTABLE_PATH" | grep -q "x86_64"; then
  echo "Release executable is missing x86_64 architecture." >&2
  exit 1
fi

codesign \
  --force \
  --options runtime \
  --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" \
  "$APP_DIR"

rm -rf "$ARTIFACT_DIR"
mkdir -p "$ARTIFACT_DIR"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --wait

xcrun stapler staple "$APP_DIR"

if [[ -n "${SPARKLE_GENERATE_APPCAST:-}" ]]; then
  "$SPARKLE_GENERATE_APPCAST" "$ARTIFACT_DIR"
else
  echo "Set SPARKLE_GENERATE_APPCAST to generate a Sparkle appcast for the release artifact."
fi

echo "$ZIP_PATH"
