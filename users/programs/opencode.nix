{ pkgs, lib, ... }:
let
  ai = import ../../modules/services/ai/models.nix;
  allAddresses = import ../../modules/addresses.nix;
  firecrawlPort = allAddresses.hosts.yifuwuqi.services.firecrawl.port;

  # Port of yifuwuqi's llama-server unit (the yifuwuqi registry entry with a
  # `port` — see modules/services/ai/llama-cpp.nix).
  localPort =
    (lib.head (
      lib.attrValues (
        lib.filterAttrs (_n: m: (m.targetHost or null) == "yifuwuqi" && m ? port) ai.local.models
      )
    )).port;
in
{
  programs.opencode = {
    enable = true;
    package = pkgs.opencode;

    context = builtins.readFile ./opencode-rules.md;

    settings = {
      model = "deepseek/deepseek-v4-flash";
      default_agent = "research";
      enabled_providers = [
        "deepseek"
        "local"
      ];
      agent = {
        plan.variant = "max";
        research = {
          description = "Current web research through self-hosted Firecrawl";
          mode = "primary";
          # Served by the Vulkan llama-server unit on yifuwuqi
          # (127.0.0.1:11436, 32k ctx). ROCm on this APU corrupts prompts
          # beyond ~4k tokens; Vulkan does not.
          model = "local/qwen2.5:7b";
          temperature = 0.2;

          # Gate via tools only. Do not set permission."*" = "deny" here:
          # OpenCode last-match can let that blanket deny win over
          # firecrawl_* allows when rules are merged.
          # Search-only: the proven fast path. Scrape stays advertised for
          # other agents (DeepSeek handles any schema); re-adding it here is
          # a follow-up once e2e is green.
          tools = {
            "*" = false;
            firecrawl_search = true;
          };
          permission = {
            firecrawl_search = "allow";
          };

          # Query strategy for the local 7B: the failure mode observed in e2e
          # is phrase-shaped queries ("latest news in brazil" with quotes or
          # site: operators), which match portal landing pages instead of
          # news items. Short keyword queries surface fresh dated results.
          prompt = ''
            Search strategy (follow strictly):
            1. Write SHORT keyword queries: entity + place + topic (e.g. "brazil news", "brazil election july 2026"). NEVER write relative-date words like "latest", "recent" or "last week" — engines match them as literal text and return old pages. For current events, add the current month and year instead (today's date is in the system prompt).
            2. NEVER wrap the query in quotes and NEVER use site:, -site:, filetype: or similar operators — the backend matches them literally and returns junk.
            3. Run ONE search, then check the dates in the result titles/descriptions. If the top results are older than 14 days or have no dates, run ONE more search with different keywords before answering.
            4. In the answer, give each item its URL and the date exactly as shown in its result. If a result shows no date, write "no date" — never invent timestamps.
          '';
        };
      };
      provider = {
        deepseek.options.apiKey = "{file:/run/secrets/tokens/deepseek}";
        local = {
          name = "Local";
          npm = "@ai-sdk/openai-compatible";
          options.baseURL = "http://127.0.0.1:${toString localPort}/v1";
          models = ai.local.opencodeModels;
        };
      };

      # Own zero-dependency MCP server (users/programs/firecrawl-mcp.js):
      # natively named tools search/scrape -> OpenCode registers the canonical
      # firecrawl_search / firecrawl_scrape, with small whitelisted schemas.
      mcp = {
        firecrawl = {
          type = "local";
          command = [
            "${pkgs.nodejs}/bin/node"
            ./firecrawl-mcp.js
          ];
          environment = {
            FIRECRAWL_API_URL = "http://localhost:${toString firecrawlPort}";
          };
        };
      };

      permission = {
        webfetch = "allow";
        websearch = "allow";
        question = "allow";
        task = "ask";
        firecrawl_search = "allow";
        firecrawl_scrape = "allow";
      };
    };
  };
}
