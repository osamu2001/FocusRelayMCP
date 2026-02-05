#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_SRC="$ROOT_DIR/Plugin/FocusRelayBridge.omnijs"

# Detect OmniFocus plugin directories in priority order
# Priority: User's custom linked folders > iCloud > Sandbox > Legacy

echo "🔍 Detecting OmniFocus plugin directory..."

# Candidate plugin locations (priority order)
CANDIDATES=()
SANDBOX_DIR=""
ICLOUD_DIR=""
LEGACY_DIR=""

# Priority 1: Check if user has configured custom plugin folders via defaults
# Use a short timeout because `defaults read` can hang on some systems.
CUSTOM_PLUGINS=$(
python3 - <<'PY'
import subprocess
try:
    result = subprocess.run(
        ["defaults", "read", "com.omnigroup.OmniFocus4", "PlugInFolders"],
        capture_output=True,
        text=True,
        timeout=2,
    )
    if result.returncode == 0:
        print(result.stdout.strip())
except subprocess.TimeoutExpired:
    pass
PY
)

if [ -n "$CUSTOM_PLUGINS" ]; then
    # Extract the first custom plugin folder path from plist
    FIRST_CUSTOM=$(echo "$CUSTOM_PLUGINS" | grep -o '"[^"]*"' | head -1 | tr -d '"')
    if [ -n "$FIRST_CUSTOM" ] && [ -d "$FIRST_CUSTOM" ]; then
        PLUGIN_DIR="$FIRST_CUSTOM"
        echo "✅ Found custom plugin folder: $PLUGIN_DIR"
    fi
fi

# Priority 2: Check for OmniFocus 4 sandbox directory (most common)
if [ -z "${PLUGIN_DIR:-}" ]; then
    SANDBOX_DIR="$HOME/Library/Containers/com.omnigroup.OmniFocus4/Data/Library/Application Support/Plug-Ins"
    CANDIDATES+=("$SANDBOX_DIR")
fi

# Priority 3: Check for iCloud sync directory
if [ -z "${PLUGIN_DIR:-}" ]; then
    ICLOUD_DIR="$HOME/Library/Mobile Documents/iCloud~com~omnigroup~OmniFocus/Documents/Plug-Ins"
    CANDIDATES+=("$ICLOUD_DIR")
fi

# Priority 4: Legacy Application Support (OmniFocus 3 and earlier)
if [ -z "${PLUGIN_DIR:-}" ]; then
    LEGACY_DIR="$HOME/Library/Application Support/OmniFocus/Plug-Ins"
    CANDIDATES+=("$LEGACY_DIR")
fi

install_plugin() {
    PLUGIN_DIR="$1"
    PLUGIN_SRC="$2"
    python3 - <<'PY'
import os
import shutil
import signal
import sys

plugin_dir = os.environ["PLUGIN_DIR"]
plugin_src = os.environ["PLUGIN_SRC"]
timeout_seconds = 5

def handle_timeout(signum, frame):
    raise TimeoutError("Timed out while accessing plugin directory")

signal.signal(signal.SIGALRM, handle_timeout)
signal.alarm(timeout_seconds)

try:
    os.makedirs(plugin_dir, exist_ok=True)
    dest = os.path.join(plugin_dir, "FocusRelayBridge.omnijs")
    if os.path.exists(dest):
        shutil.rmtree(dest)
    shutil.copytree(plugin_src, dest)
    signal.alarm(0)
    print(plugin_dir)
except TimeoutError:
    sys.exit(2)
except Exception as exc:
    print(f"ERROR: {exc}", file=sys.stderr)
    sys.exit(1)
PY
}

if [ -n "${PLUGIN_DIR:-}" ]; then
    CANDIDATES=("$PLUGIN_DIR")
else
    CANDIDATES=("${CANDIDATES[@]}")
fi

PLUGIN_DIR=""
for candidate in "${CANDIDATES[@]}"; do
    export PLUGIN_DIR="$candidate"
    export PLUGIN_SRC
    if output=$(install_plugin "$candidate" "$PLUGIN_SRC" 2>/dev/null); then
        PLUGIN_DIR="$output"
        if [ "$candidate" = "$SANDBOX_DIR" ]; then
            echo "✅ Found OmniFocus 4 sandbox plugin directory"
        elif [ "$candidate" = "$ICLOUD_DIR" ]; then
            echo "✅ Found iCloud-synced plugin directory"
        elif [ "$candidate" = "$LEGACY_DIR" ]; then
            echo "⚠️  Using legacy plugin directory (OmniFocus 3 or earlier)"
        else
            echo "✅ Found custom plugin folder: $PLUGIN_DIR"
        fi
        break
    else
        if [ $? -eq 2 ]; then
            echo "⚠️  Timed out accessing $candidate, trying next location..."
        fi
    fi
done

if [ -z "$PLUGIN_DIR" ]; then
    echo "❌ Failed to install plugin in any known OmniFocus directory."
    exit 1
fi

echo ""
echo "✅ Successfully installed FocusRelayBridge.omnijs to:"
echo "   $PLUGIN_DIR"
echo ""
echo "🔄 IMPORTANT: You MUST restart OmniFocus completely for changes to take effect."
echo ""
echo "   Run this command:"
echo "   osascript -e 'tell application \"OmniFocus\" to quit' && sleep 2 && open -a \"OmniFocus\""
echo ""
echo "⚠️  NOTE: The first time you run a query, OmniFocus will ask you to approve"
echo "   the automation script. Click \"Run Script\" when prompted."
