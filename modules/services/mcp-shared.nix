# Shared MCP endpoint definitions for local AI clients/services.
let
  searxngHost = "127.0.0.1";
  searxngPort = 3001;
  searxngBaseUrl = "http://${searxngHost}:${toString searxngPort}";
  searxngMcpUrl = "${searxngBaseUrl}/mcp";
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

    librechat = {
      searxng = {
        type = "streamable-http";
        url = searxngMcpUrl;
        serverInstructions = true;
      };
    };
  };
}
