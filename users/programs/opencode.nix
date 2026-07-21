{ pkgs, osConfig, ... }:
let
  ai = import ../../modules/services/ai/models.nix;
  allAddresses = import ../../modules/addresses.nix;
  firecrawlPort = allAddresses.hosts.${osConfig.networking.hostName}.services.firecrawl.port;
in
{
  programs.opencode = {
    enable = true;
    package = pkgs.opencode;

    context = builtins.readFile ./opencode-rules.md;

    settings = {
      model = "deepseek/deepseek-v4-flash";
      default_agent = "plan";
      enabled_providers = [
        "deepseek"
        "local"
      ];
      agent.plan = {
        variant = "max";
      };
      provider = {
        deepseek.options.apiKey = "{file:/run/secrets/tokens/deepseek}";
        local = {
          name = "Local";
          npm = "@ai-sdk/openai-compatible";
          options.baseURL = "http://127.0.0.1:11434/v1";
          models = ai.local.opencodeModels;
        };
      };

      permission = {
        webfetch = "allow";
        websearch = "allow";
        question = "allow";
        task = "ask";
      };
    };
  };

  home.file.".config/opencode/mcp.json".text = builtins.toJSON {
    mcpServers = {
      firecrawl = {
        command = "npx";
        args = [
          "-y"
          "@mendable/firecrawl-mcp-server"
        ];
        env = {
          FIRECRAWL_API_URL = "http://localhost:${toString firecrawlPort}";
          FIRECRAWL_API_KEY = "this_is_just_a_dummy_key";
        };
      };
    };
  };
}
