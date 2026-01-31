# Homebrew Formula for FocusRelayMCP
# This formula installs both the MCP server binary and the OmniFocus plugin

class FocusRelayMcp < Formula
  desc "MCP server for OmniFocus - query tasks via AI assistants"
  homepage "https://github.com/deverman/FocusRelayMCP"
  url "https://github.com/deverman/FocusRelayMCP/releases/download/v1.0.0/focus-relay-mcp-1.0.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"

  depends_on :macos
  depends_on arch: :arm64

  def install
    # Install the MCP server binary
    bin.install "focus-relay-mcp"
    
    # Install the OmniFocus plugin to a shared location
    plugin_share = "#{share}/focus-relay-mcp"
    mkdir_p plugin_share
    cp_r "Plugin/FocusRelayBridge.omnijs", plugin_share
    
    # Create a post-install script to link the plugin to OmniFocus
    (bin/"focus-relay-mcp-install-plugin").write <<~EOS
      #!/bin/bash
      set -e
      
      PLUGIN_SRC="#{plugin_share}/FocusRelayBridge.omnijs"
      
      # Detect OmniFocus plugin directory
      SANDBOX_DIR="$HOME/Library/Containers/com.omnigroup.OmniFocus4/Data/Library/Application Support/OmniFocus/Plug-Ins"
      ICLOUD_DIR="$HOME/Library/Mobile Documents/iCloud~com~omnigroup~OmniFocus/Documents/Plug-Ins"
      LEGACY_DIR="$HOME/Library/Application Support/OmniFocus/Plug-Ins"
      
      if [ -d "$SANDBOX_DIR" ]; then
        PLUGIN_DIR="$SANDBOX_DIR"
      elif [ -d "$ICLOUD_DIR" ]; then
        PLUGIN_DIR="$ICLOUD_DIR"
      else
        PLUGIN_DIR="$LEGACY_DIR"
      fi
      
      mkdir -p "$PLUGIN_DIR"
      rm -rf "$PLUGIN_DIR/FocusRelayBridge.omnijs"
      cp -R "$PLUGIN_SRC" "$PLUGIN_DIR/"
      
      echo "✅ OmniFocus plugin installed to: $PLUGIN_DIR"
      echo ""
      echo "🔄 IMPORTANT: Restart OmniFocus now!"
      echo "   Run: osascript -e 'tell app \"OmniFocus\" to quit' && sleep 2 && open -a \"OmniFocus\""
      echo ""
      echo "⚠️  First time setup: When you run a query, click 'Run Script' in the security dialog"
    EOS
    chmod 0755, bin/"focus-relay-mcp-install-plugin"
    
    # Install the plugin automatically during brew install
    system bin/"focus-relay-mcp-install-plugin"
  end

  def caveats
    <<~EOS
      ✅ FocusRelayMCP has been installed!

      📍 Binary location: #{opt_bin}/focus-relay-mcp
      🔌 Plugin location: Detected and installed automatically

      🔄 NEXT STEPS:

      1. RESTART OmniFocus completely (Cmd+Q, then reopen)
         This is required for the plugin to load.

      2. CONFIGURE your MCP client (Claude Desktop, opencode, etc.):
         
         Add to your config:
         {
           "mcp": {
             "focus-relay-mcp": {
               "type": "local",
               "command": ["#{opt_bin}/focus-relay-mcp"],
               "enabled": true
             }
           }
         }

         Claude Desktop config: ~/Library/Application\ Support/Claude/claude_desktop_config.json
         opencode config: ~/.config/opencode/opencode.json

      ⚠️  FIRST TIME SETUP:
      When you run your first query, OmniFocus will show a security dialog:
      "An unknown application is attempting to run an Omni Automation Script"
      
      → Click "Run Script" to approve (required for the plugin to work)

      🔧 If you need to reinstall the plugin later:
         run: #{opt_bin}/focus-relay-mcp-install-plugin

      📖 Full documentation: https://github.com/deverman/FocusRelayMCP
    EOS
  end

  test do
    system "#{bin}/focus-relay-mcp", "--help"
  end
end
