# Shared MCP server declarations: single source of truth in `programs.mcp`.
# Consumed natively by OpenCode (`enableMcpIntegration`), Antigravity
# (`programs.antigravity-cli`), Claude Code (`programs.claude-code`), and
# Cursor (`~/.cursor/mcp.json` linked directly to the generated `mcp.json`).
{
  pkgs,
  lib,
  config,
  osConfig ? null,
  ...
}:
let
  inherit (import ../../modules/addresses.nix) hosts;
  hostName = if osConfig == null then null else osConfig.networking.hostName;
  # Firecrawl and SearXNG bind loopback/host-local on yifuwuqi only; remote
  # hosts cannot reach localhost:24002 or localhost:24888.
  onYifuwuqi = hostName == "yifuwuqi";
in
{
  config = lib.mkIf (config.serverMode.developer && onYifuwuqi) {
    programs = {
      mcp = {
        enable = true;
        servers.firecrawl = {
          command = lib.getExe (pkgs.callPackage ../../packages/firecrawl-mcp { });
          env = {
            FIRECRAWL_API_URL = "http://localhost:${toString hosts.yifuwuqi.services.firecrawl.port}";
            SEARXNG_URL = "http://localhost:${toString hosts.yifuwuqi.services.searxng.port}";
          };
        };
      };

      antigravity-cli = {
        enable = true;
        package = null;
        enableMcpIntegration = true;
      };

      claude-code = {
        enable = true;
        package = null;
        enableMcpIntegration = true;
      };
    };

    # Home Manager's `programs.cursor` writes VS Code's `~/.config/Cursor/User/mcp.json`,
    # whereas Cursor IDE/CLI/server reads `~/.cursor/mcp.json` (`{ "mcpServers": ... }`).
    home.file.".cursor/mcp.json".source = config.xdg.configFile."mcp/mcp.json".source;
  };
}
