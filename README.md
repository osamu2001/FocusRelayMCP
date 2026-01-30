# FocusRelayMCP

Local MCP server for OmniFocus (macOS) using OSAKit + Omni Automation.

## Build

```sh
swift build
```

## Run (stdio MCP server)

```sh
swift run focus-relay-mcp
```

## Bridge Mode (Omni Automation via omnijs-run)

Use the file-based IPC bridge and execute inside OmniFocus' Omni Automation context:

```sh
swift run focus-relay-mcp
```

Bridge mode requires OmniFocus to allow automation and a plug-in bridge installed.

### Install Plug-In

```sh
./scripts/install-plugin.sh
```

If OmniFocus is running, reload plug-ins:

- OmniFocus menu: Automation > Plug-Ins > Reload Plug-Ins

Restart is usually not required after reload.

### Quick Checklist

1) Install plug-in: `./scripts/install-plugin.sh`
2) Reload plug-ins in OmniFocus
3) Set OpenCode MCP `environment` to enable bridge mode
4) Run `focus-relay-mcp_bridge_health_check`

### Package Plug-In (optional)

```sh
./scripts/package-plugin.sh
```

### Bridge Health Check

In OpenCode, run:

```
Call focus-relay-mcp_bridge_health_check
```

### Troubleshooting

If the bridge times out:

1) Confirm `FOCUS_RELAY_USE_BRIDGE=1` in OpenCode MCP `environment`
2) Reload OmniFocus plug-ins
3) Verify IPC path exists:
   `~/Library/Containers/com.omnigroup.OmniFocus4/Data/Documents/FocusRelayIPC`
4) Re-run health check

## Tests

Unit tests:

```sh
swift test
```

Live OmniFocus integration test (requires OmniFocus running and Automation permission):

```sh
FOCUS_RELAY_LIVE_TESTS=1 swift test --filter OmniFocusIntegrationTests
```

Bridge integration tests (requires plug-in installed and OmniFocus running):

```sh
FOCUS_RELAY_BRIDGE_TESTS=1 swift test --filter OmniFocusIntegrationTests
```

Optional: assert a specific inbox task name exists:

```sh
FOCUS_RELAY_LIVE_TESTS=1 \
FOCUS_RELAY_EXPECT_INBOX_TASK="My known inbox task" \
swift test --filter OmniFocusIntegrationTests
```

## MCP Client Config (generic)

```json
{
  "mcpServers": {
    "focus-relay-mcp": {
      "command": "/path/to/focus-relay-mcp",
      "args": []
    }
  }
}
```

## OpenCode MCP Config

Add this to your OpenCode config (`~/.config/opencode/opencode.json` or project `opencode.json`):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "focus-relay-mcp": {
      "type": "local",
      "command": ["/path/to/.build/release/focus-relay-mcp"],
      "enabled": true
    }
  }
}
```

Build a release binary:

```sh
swift build -c release
```

Binary output:

```
.build/release/focus-relay-mcp
```
