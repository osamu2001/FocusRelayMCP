#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_SRC="$ROOT_DIR/Plugin/FocusRelayBridge.omnijs"
DIST_DIR="$ROOT_DIR/dist"

mkdir -p "$DIST_DIR"
ZIP_PATH="$DIST_DIR/FocusRelayBridge.omnijs.zip"

rm -f "$ZIP_PATH"
cd "$ROOT_DIR/Plugin"
zip -r "$ZIP_PATH" "FocusRelayBridge.omnijs" >/dev/null

echo "Packaged plug-in: $ZIP_PATH"
