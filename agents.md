# Project Agent Notes

- Use the Swift Testing framework built into the Swift toolchain (`Testing` module, `@Test`, `#expect`).
- Do not add `swift-testing` as a package dependency.
- Add or update Swift tests when new functionality is added.
- Run `swift test` after changes.

## Plugin Installation

When the FocusRelayBridge plugin needs to be updated in OmniFocus, **always use the install script**:

```bash
./scripts/install-plugin.sh
```

This script automatically detects the correct OmniFocus plugin directory (iCloud, sandboxed, or legacy).

⚠️ **Critical**: After installation, **restart OmniFocus completely** (not just reload):

```bash
osascript -e 'tell application "OmniFocus" to quit' && sleep 2 && open -a "OmniFocus"
```

The plugin JavaScript is cached by OmniFocus and requires a full restart to pick up changes.

## Timezone Handling

The MCP server automatically detects the user's local timezone from macOS system settings:

- **Detection**: `TimeZone.current.identifier` (e.g., "Asia/Singapore", "America/New_York")
- **Propagation**: Passed via `userTimeZone` field in every `BridgeRequest`
- **Usage**: JavaScript plugin can calculate morning/afternoon/evening in local time before converting to UTC

This ensures that time-based queries ("What should I do this morning?") work correctly regardless of the user's location.

## Performance Optimizations

### JavaScript Layer (BridgeLibrary.js)
- **Single-pass filtering**: All filter conditions checked in one iteration (was 10+ passes)
- **Early exit**: Stop processing after reaching page limit (e.g., 10 tasks instead of 2874)
- **Pre-parsed dates**: Parse filter dates once, reuse timestamps

### Swift Layer
- **Faster polling**: Reduced `waitForResponse` interval from 100ms to 50ms
- **Removed debug overhead**: Cleaned up print statements and logging

### Impact
- Task filtering: Now sub-millisecond (was 50-100ms with multiple passes)
- End-to-end latency: Still ~1s (dominated by IPC/file I/O, not code)

## Caching Strategy

The MCP server implements an **actor-based caching layer** (`CatalogCache`) for frequently accessed, slowly-changing data:

### Current Implementation
- **Location**: `Sources/OmniFocusAutomation/CatalogCache.swift`
- **TTL**: 300 seconds (5 minutes) for projects and tags
- **Cache Keys**: Based on pagination (limit, cursor) and requested fields
- **Thread Safety**: Uses Swift `actor` for safe concurrent access

### What's Cached
- ✅ **Projects** (`list_projects`) - Cached with 5-minute TTL
- ✅ **Tags** (`list_tags`) - Cached with 5-minute TTL
- ❌ **Tasks** (`list_tasks`) - Not cached (changes frequently)

### Cache Invalidation
- Automatic expiration after TTL
- No manual invalidation currently implemented
- Future: Invalidate on write operations when write tools are added

### Performance Impact
- Projects/Tags queries: ~300ms → ~10ms (30x faster on cache hit)
- Task queries: No caching (always fresh data)

## Release Process

When creating a new release (via GitHub Actions or manually), follow these steps:

### 1. Create Release Tag
```bash
git tag -a vX.X.X -m "Release vX.X.X: Description of changes"
git push origin vX.X.X
```

### 2. Update Homebrew Formula (CRITICAL)
The Homebrew tap must be updated with the new SHA256:

1. **Get the new SHA256** from the release:
   ```bash
   curl -sL https://github.com/deverman/FocusRelayMCP/releases/download/vX.X.X/focus-relay-mcp-X.X.X.sha256
   ```

2. **Update the formula** in `deverman/homebrew-focus-relay`:
   ```bash
   cd ~/homebrew-focus-relay  # or wherever you cloned it
   # Edit focus-relay-mcp.rb and update:
   # - version number in URL
   # - sha256 value
   git add focus-relay-mcp.rb
   git commit -m "Update formula to vX.X.X"
   git push origin main
   ```

3. **Verify the tap works**:
   ```bash
   brew update
   brew install focus-relay-mcp
   ```

### 3. GitHub Release Notes
The GitHub Actions workflow auto-generates release notes, but add:
- Summary of major changes
- Breaking changes (if any)
- Link to CHANGELOG.md

### Future Improvements
- Add task caching with shorter TTL (30-60 seconds)
- Implement cache warming for startup
- Add cache statistics/metrics endpoint
- Add cache control parameter (`skipCache: true`) for users needing fresh data
- **INVESTIGATE:** Use task/project notes field effectively with MCP for additional context
  - Research how to extract meaningful context from notes
  - Consider semantic search or summarization of note content
  - Potential use cases: finding tasks by note content, summarizing project notes
  - Challenge: Notes can be large, need efficient indexing/search strategy
