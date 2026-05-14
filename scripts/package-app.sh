#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-debug}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Display Recall"
EXECUTABLE_NAME="DisplayRecall"
BUNDLE_ID="dev.wbbb.display-recall"
MINIMUM_SYSTEM_VERSION="13.0"
BUILD_ROOT="$ROOT_DIR/.build/apple"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
VERSION="0.1.0"
BUILD_NUMBER="1"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://github.com/wbbb/display-recall/releases/latest/download/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"

BUILD_ARGUMENTS=(swift build --configuration "$CONFIGURATION" --scratch-path "$BUILD_ROOT")
if [[ "$CONFIGURATION" == "release" ]]; then
  BUILD_ARGUMENTS+=(--arch arm64 --arch x86_64)
fi

"${BUILD_ARGUMENTS[@]}"

EXECUTABLE_PATH="$(find "$BUILD_ROOT" -path "*/$CONFIGURATION/$EXECUTABLE_NAME" -type f | head -n 1)"
if [[ -z "$EXECUTABLE_PATH" ]]; then
  echo "Could not find built executable: $EXECUTABLE_NAME" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$EXECUTABLE_PATH" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"

find "$BUILD_ROOT" -path "*/$CONFIGURATION/*.bundle" -type d -maxdepth 5 | while read -r bundle; do
  cp -R "$bundle" "$APP_DIR/Contents/Resources/"
done

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MINIMUM_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>SUEnableAutomaticChecks</key>
  <false/>
  <key>SUFeedURL</key>
  <string>$SPARKLE_FEED_URL</string>
  <key>SUPublicEDKey</key>
  <string>$SPARKLE_PUBLIC_ED_KEY</string>
</dict>
</plist>
PLIST

echo "$APP_DIR"
