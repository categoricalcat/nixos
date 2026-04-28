{ pkgs, inputs, ... }:
let
  unstable = import ../../modules/nixpkgs-unstable.nix { inherit inputs pkgs; };
  sharedMcp = import ../../modules/services/ai/mcp.nix;
  ai = import ../../modules/services/ai/models.nix;
in
{
  programs.opencode = {
    enable = true;
    package = unstable.opencode;

    rules = builtins.readFile ./opencode-rules.md;

    settings = {
      "$schema" = "https://opencode.ai/config.json";
      model = "deepseek/deepseek-chat";
      enabled_providers = [
        "deepseek"
        "local"
      ];
      provider = {
        deepseek.options.apiKey = "{file:/run/secrets/tokens/deepseek}";
        local = {
          name = "Local";
          npm = "@ai-sdk/openai-compatible";
          options.baseURL = "http://127.0.0.1:11434/v1";
          models = ai.local.opencodeModels;
        };
      };

      mcp = sharedMcp.searxng.opencode // sharedMcp.playwright.opencode;
    };
  };
}
