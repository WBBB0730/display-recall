#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/Sources/DisplayRecallCore/Resources/Backends"
VERSION="1.4.0"
TAG="v1.4.0"
BASE_URL="https://github.com/jakehilborn/displayplacer/releases/download/$TAG"

APPLE_FILE="displayplacer-apple-v140"
APPLE_SHA256="0572c3d2918e47c7e0b9d7723907864e2ea2b53b9d3b02379769fffcf44f7ea0"
INTEL_FILE="displayplacer-intel-v140"
INTEL_SHA256="13ec0351ed7849b22e945974f1d4ac91eca30b38b09ec962c497feb8297eac2b"

download_and_verify() {
  local file_name="$1"
  local expected_sha="$2"
  local destination="$BACKEND_DIR/$file_name"

  echo "Fetching displayplacer $VERSION: $file_name"
  curl -fL --retry 3 --retry-delay 2 -o "$destination" "$BASE_URL/$file_name"

  local actual_sha
  actual_sha="$(shasum -a 256 "$destination" | awk '{print $1}')"
  if [[ "$actual_sha" != "$expected_sha" ]]; then
    rm -f "$destination"
    echo "Checksum mismatch for $file_name" >&2
    echo "Expected: $expected_sha" >&2
    echo "Actual:   $actual_sha" >&2
    exit 1
  fi

  chmod 755 "$destination"
}

mkdir -p "$BACKEND_DIR"
download_and_verify "$APPLE_FILE" "$APPLE_SHA256"
download_and_verify "$INTEL_FILE" "$INTEL_SHA256"

echo "displayplacer $VERSION backends are ready in $BACKEND_DIR"
