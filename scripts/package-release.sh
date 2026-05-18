#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Display Recall"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
ARTIFACT_DIR="$ROOT_DIR/dist/release"
VERSION="${VERSION:-0.1.1}"
DMG_PATH="$ARTIFACT_DIR/Display-Recall-$VERSION.dmg"

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

rm -rf "$ARTIFACT_DIR"
mkdir -p "$ARTIFACT_DIR"

CREATE_DMG_COMMAND=(create-dmg)
if ! command -v create-dmg >/dev/null 2>&1; then
  CREATE_DMG_COMMAND=(npx --yes create-dmg)
fi

"${CREATE_DMG_COMMAND[@]}" "$APP_DIR" "$ARTIFACT_DIR" \
  --overwrite \
  --dmg-title="$APP_NAME" \
  --no-code-sign

GENERATED_DMG_PATH="$(find "$ARTIFACT_DIR" -maxdepth 1 -name "$APP_NAME*.dmg" -type f | head -n 1)"
if [[ -z "$GENERATED_DMG_PATH" ]]; then
  echo "Could not find generated DMG artifact." >&2
  exit 1
fi

if [[ "$GENERATED_DMG_PATH" != "$DMG_PATH" ]]; then
  mv "$GENERATED_DMG_PATH" "$DMG_PATH"
fi

if [[ -n "${SPARKLE_GENERATE_APPCAST:-}" ]]; then
  "$SPARKLE_GENERATE_APPCAST" "$ARTIFACT_DIR"
else
  echo "Set SPARKLE_GENERATE_APPCAST to generate a Sparkle appcast for the release artifact."
fi

echo "$DMG_PATH"
