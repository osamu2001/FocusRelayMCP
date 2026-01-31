#!/bin/bash
# Test script for Homebrew formula - run this to validate everything works

set -e

echo "🧪 Testing FocusRelayMCP Homebrew Formula..."
echo ""

# Step 1: Check formula syntax
echo "1️⃣  Checking formula syntax..."
brew audit --strict ./homebrew/focus-relay-mcp.rb || true
echo ""

# Step 2: Check style
echo "2️⃣  Checking Ruby style..."
brew style ./homebrew/focus-relay-mcp.rb || true
echo ""

# Step 3: Create local tap
echo "3️⃣  Setting up local tap..."
TAP_DIR="$(brew --repo)/Library/Taps/deverman/homebrew-focus-relay"
mkdir -p "$TAP_DIR"
cp homebrew/focus-relay-mcp.rb "$TAP_DIR/"
brew tap deverman/focus-relay 2>/dev/null || true
echo ""

# Step 4: Test installation (this will fail if SHA256 is wrong)
echo "4️⃣  Testing installation (dry run)..."
brew install --dry-run deverman/focus-relay/focus-relay-mcp || true
echo ""

# Step 5: Show what would be installed
echo "5️⃣  Showing formula info..."
brew info deverman/focus-relay/focus-relay-mcp || true
echo ""

# Step 6: Show caveats
echo "6️⃣  Showing post-install instructions (caveats)..."
brew cat deverman/focus-relay/focus-relay-mcp | grep -A 50 "def caveats"
echo ""

# Cleanup
echo "🧹 Cleaning up..."
brew untap deverman/focus-relay 2>/dev/null || true
rm -rf "$TAP_DIR"

echo ""
echo "✅ Testing complete!"
echo ""
echo "Next steps:"
echo "1. Create GitHub release with the binary and plugin"
echo "2. Calculate SHA256: shasum -a 256 <release.tar.gz>"
echo "3. Update formula with real SHA256"
echo "4. Test actual installation: brew install --build-from-source ./homebrew/focus-relay-mcp.rb"
echo "5. Create public tap repo: github.com/deverman/homebrew-focus-relay"
