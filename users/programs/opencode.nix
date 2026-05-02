{ pkgs, inputs, ... }:
let
  unstable = import ../../modules/nixpkgs-unstable.nix { inherit inputs pkgs; };
  ai = import ../../modules/services/ai/models.nix;
in
{
  programs.opencode = {
    enable = true;
    package = unstable.opencode;

    rules = builtins.readFile ./opencode-rules.md;

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
}
