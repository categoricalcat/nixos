_: {
  programs.opencode = {
    enable = true;
    settings = {
      "$schema" = "https://opencode.ai/config.json";
      model = "deepseek/deepseek-chat";
      enabled_providers = [
        "deepseek"
        "ollama"
        "gemini"
      ];
      provider = {
        gemini.options.apiKey = "{file:/run/secrets/tokens/gemini}";
        deepseek.options.apiKey = "{file:/run/secrets/tokens/deepseek}";
        ollama = {
          name = "Ollama";
          npm = "@ai-sdk/openai-compatible";
          options.baseURL = "http://127.0.0.1:11434/v1";
          models = {
            "deepseek-r1:8b" = {
              _launch = true;
              name = "deepseek-r1:8b";
            };
            "deepseek-v3.2:cloud" = {
              _launch = true;
              name = "deepseek-v3.2:cloud";
              limit = {
                context = 163840;
                output = 65536;
              };
            };
          };
        };
      };
    };
  };
}
