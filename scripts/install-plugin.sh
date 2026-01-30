#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_SRC="$ROOT_DIR/Plugin/FocusRelayBridge.omnijs"

ICLOUD_DIR="$HOME/Library/Mobile Documents/iCloud~com~omnigroup~OmniFocus/Documents/Plug-Ins"
SANDBOX_DIR="$HOME/Library/Containers/com.omnigroup.OmniFocus4/Data/Library/Application Support/OmniFocus/Plug-Ins"
LEGACY_DIR="$HOME/Library/Application Support/OmniFocus/Plug-Ins"

if [ -d "$ICLOUD_DIR" ]; then
  PLUGIN_DIR="$ICLOUD_DIR"
elif [ -d "$SANDBOX_DIR" ]; then
  PLUGIN_DIR="$SANDBOX_DIR"
else
  PLUGIN_DIR="$LEGACY_DIR"
fi

mkdir -p "$PLUGIN_DIR"
rm -rf "$PLUGIN_DIR/FocusRelayBridge.omnijs"
cp -R "$PLUGIN_SRC" "$PLUGIN_DIR/FocusRelayBridge.omnijs"

echo "Installed FocusRelayBridge.omnijs to: $PLUGIN_DIR"
echo "If OmniFocus is running, use Automation > Plug-Ins > Reload Plug-Ins."
