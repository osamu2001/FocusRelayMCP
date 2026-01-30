# Homebrew Formula for FocusRelayMCP
# Save this file as focus-relay-mcp.rb in your Homebrew tap

class FocusRelayMcp < Formula
  desc "MCP server for OmniFocus - query tasks via AI assistants"
  homepage "https://github.com/deverman/FocusRelayMCP"
  url "https://github.com/deverman/FocusRelayMCP/releases/download/v1.0.0/focus-relay-mcp-1.0.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"

  depends_on :macos
  depends_on arch: :arm64 # or :x86_64 depending on your build

  def install
    bin.install "focus-relay-mcp"
    
    # Install the OmniFocus plugin
    plugin_dir = "#{HOMEBREW_PREFIX}/share/focus-relay-mcp"
    mkdir_p plugin_dir
    cp_r "Plugin/FocusRelayBridge.omnijs", plugin_dir
    
    # Create a post-install message
    ohai "FocusRelayMCP installed successfully!"
    ohai "Next steps:"
    ohai "1. Install the OmniFocus plugin:"
    ohai "   brew link focus-relay-mcp"
    ohai "2. Restart OmniFocus completely"
    ohai "3. Configure your MCP client to use: #{opt_bin}/focus-relay-mcp"
  end

  def caveats
    <<~EOS
      ⚠️  IMPORTANT: OmniFocus Plugin Installation Required

      The FocusRelayMCP server requires an OmniFocus plugin to function.
      
      To install the plugin:
        1. Open OmniFocus
        2. Go to Automation > Plug-Ins > Show Plug-In Folder in Finder
        3. Copy FocusRelayBridge.omnijs to that folder:
           cp #{HOMEBREW_PREFIX}/share/focus-relay-mcp/FocusRelayBridge.omnijs \
              ~/Library/Containers/com.omnigroup.OmniFocus4/Data/Library/Application\\ Support/OmniFocus/Plug-Ins/
        4. Restart OmniFocus completely
      
      ⚠️  First Time Setup:
      When you first run a query, OmniFocus will show a security dialog.
      You MUST click "Run Script" to allow the automation.
      
      📖 Documentation: https://github.com/deverman/FocusRelayMCP#readme
    EOS
  end

  test do
    system "#{bin}/focus-relay-mcp", "--help"
  end
end
