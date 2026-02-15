# Session Notes (FocusRelayMCP)

## Current Status
- End-to-end manual checks completed:
  - `focusrelay` installed via local Homebrew tap; `which focusrelay` resolves to `/opt/homebrew/bin/focusrelay`.
  - Plugin installed via `./scripts/install-plugin.sh` and OmniFocus restarted.
  - CLI query works: `focusrelay list-tasks --limit 5 --fields id,name,available` returns data.
- MCP server expected to run via `focusrelay serve` (config key: `focusrelay`).

## Outstanding Tasks
1. **Commit and push pending changes in this repo** (see `git status` below).
2. **Update local Homebrew tap repo** (if desired):
   - `/Users/deverman/Documents/Code/swift/homebrew-focus-relay` currently uses a local tarball URL for testing.
   - Before release, restore formula URL/SHA to GitHub release tarball and push to tap.
3. **MCP client config sanity**:
   - Ensure config uses `"focusrelay"` key and command: `["/opt/homebrew/bin/focusrelay", "serve"]`.
4. **Remove old binary** (if still present):
   - `/usr/local/bin/focus-relay-mcp` may still exist and trigger Gatekeeper dialogs.

## Pending Changes (FocusRelayMCP)
```
M Plugin/FocusRelayBridge.omnijs/Resources/BridgeLibrary.js
M Sources/FocusRelayCLI/FocusRelayCLI.swift
M opencode.json
M scripts/install-plugin.sh
```

## Key Fixes in Working Tree
- BridgeLibrary.js: `isAvailable` reference fixed to `isTaskAvailable` in task payload.
- install-plugin.sh: timeout/fallback around `defaults read` to avoid hangs.
- CLI help text: removed “(default)” from serve description.
- MCP config key renamed to `focusrelay` in opencode.json.

## Recommended Commit Message
"Fix available flag and harden plugin install"

## Commands Used for Manual Verification
- `swift build -c release`
- `./scripts/install-plugin.sh`
- `osascript -e 'tell application "OmniFocus" to quit' && sleep 2 && open -a "OmniFocus"`
- `focusrelay list-tasks --limit 5 --fields id,name,available`

