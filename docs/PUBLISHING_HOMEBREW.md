# Publishing FocusRelayMCP to Homebrew

## Prerequisites

1. **GitHub Release Created** with:
   - Binary: `focus-relay-mcp` (from `.build/release/`)
   - Plugin: `FocusRelayBridge.omnijs` (from `Plugin/`)
   - Packaged as: `focus-relay-mcp-1.0.0.tar.gz`
   
2. **SHA256 Calculated** for the release tarball

3. **Formula Updated** with real SHA256 (replace PLACEHOLDER_SHA256)

## Publishing Steps

### Option A: Personal Tap (Recommended - Fastest)

1. **Create a new GitHub repo**: `deverman/homebrew-focus-relay`
   - Can be empty, just needs to exist

2. **Push the formula to that repo:**
   ```bash
   git clone https://github.com/deverman/homebrew-focus-relay.git
   cd homebrew-focus-relay
   cp ../FocusRelayMCP/homebrew/focus-relay-mcp.rb .
   git add .
   git commit -m "Add FocusRelayMCP formula v1.0.0"
   git push origin main
   ```

3. **Users can now install:**
   ```bash
   brew tap deverman/focus-relay
   brew install focus-relay-mcp
   ```

### Option B: Homebrew Core (Official - More Discoverable)

1. **Fork Homebrew/homebrew-core**

2. **Add your formula:**
   ```bash
   cd homebrew-core
   cp ../FocusRelayMCP/homebrew/focus-relay-mcp.rb Formula/f/focus-relay-mcp.rb
   ```

3. **Submit PR to Homebrew:**
   ```bash
   git checkout -b add-focus-relay-mcp
   git add Formula/f/focus-relay-mcp.rb
   git commit -m "focus-relay-mcp 1.0.0 (new formula)"
   git push origin add-focus-relay-mcp
   # Then create PR on GitHub
   ```

4. **Requirements for Homebrew Core:**
   - Repository must be 30+ days old
   - Notable project (stars, forks)
   - Passing CI tests
   - Good documentation

## Post-Publishing

### Update README
Once published, update the README to show:

```markdown
### Quick Install (Homebrew)

```bash
brew tap deverman/focus-relay
brew install focus-relay-mcp
```

The formula automatically:
- Installs the MCP server binary
- Installs the OmniFocus plugin
- Shows configuration instructions
```

### Version Updates

When you release v1.0.1:

1. Create new GitHub release with updated binary
2. Calculate new SHA256
3. Update formula:
   ```ruby
   url "https://github.com/deverman/FocusRelayMCP/releases/download/v1.0.1/focus-relay-mcp-1.0.1.tar.gz"
   sha256 "NEW_SHA256_HERE"
   ```
4. Commit and push to tap repo
5. Users get update via `brew upgrade`

## Testing Checklist

Before publishing, verify:

- [ ] Formula installs without errors
- [ ] Binary works: `focus-relay-mcp --help`
- [ ] Plugin installs to correct OmniFocus directory
- [ ] Caveats are displayed clearly
- [ ] Uninstall works: `brew uninstall focus-relay-mcp`
- [ ] Audit passes: `brew audit --strict focus-relay-mcp`
- [ ] Style passes: `brew style focus-relay-mcp`
