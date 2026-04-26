# Shared MCP endpoint definitions for local AI clients/services.
#
# Both MCP servers run as podman sidecars on this host:
#   - SearXNG MCP via `modules/services/mcp-searxng.nix`     -> 127.0.0.1:3001
#   - Playwright MCP via `modules/services/mcp-playwright.nix` -> 127.0.0.1:3002
# Clients talk to them over loopback HTTP.
let
  searxngHost = "127.0.0.1";
  searxngPort = 3001;
  searxngBaseUrl = "http://${searxngHost}:${toString searxngPort}";
  searxngMcpUrl = "${searxngBaseUrl}/mcp";

  playwrightHost = "127.0.0.1";
  playwrightPort = 3002;
  playwrightBaseUrl = "http://${playwrightHost}:${toString playwrightPort}";
  # `/mcp` is the unified endpoint (handles both SSE streaming and
  # streamable-HTTP). `/sse` would also work, /mcp is upstream's recommended
  # default.
  playwrightMcpUrl = "${playwrightBaseUrl}/mcp";
in
{
  searxng = {
    host = searxngHost;
    port = searxngPort;
    baseUrl = searxngBaseUrl;
    mcpUrl = searxngMcpUrl;
    healthUrl = "${searxngBaseUrl}/health";

    allowedDomains = [
      "localhost"
      searxngHost
    ];

    opencode = {
      searxng = {
        type = "remote";
        url = searxngMcpUrl;
        enabled = true;
      };
    };
  };

  playwright = {
    host = playwrightHost;
    port = playwrightPort;
    baseUrl = playwrightBaseUrl;
    mcpUrl = playwrightMcpUrl;
    healthUrl = "${playwrightBaseUrl}/health";

    opencode = {
      playwright = {
        type = "remote";
        url = playwrightMcpUrl;
        enabled = true;
      };
    };
  };
}
