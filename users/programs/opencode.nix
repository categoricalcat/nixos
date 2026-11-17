{
  pkgs,
  lib,
  config,
  osConfig ? null,
  ...
}:
let
  ai = import ../../modules/services/ai/models.nix { inherit lib; };
  inherit (import ../../modules/addresses.nix) hosts;
  hostName = if osConfig == null then null else osConfig.networking.hostName;
  # Firecrawl's API listens on yifuwuqi's localhost only, so the MCP and the
  # research agent exist there alone; other hosts use the built-in default
  # agent and reach Firecrawl by ssh.
  onYifuwuqi = hostName == "yifuwuqi";
  firecrawl-mcp = pkgs.callPackage ../../packages/firecrawl-mcp { };

  # yifuwuqi's router listens on loopback only, so only yifuwuqi can reach it.
  llamaProviders = lib.filterAttrs (host: _: host != "yifuwuqi" || hostName == "yifuwuqi") {
    yifuwuqi = {
      id = "local";
      name = "Local (yifuwuqi)";
    };
    yitaishi = {
      id = "yitaishi";
      name = "Workstation (yitaishi)";
    };
  };
  # Shared by every agent that gets the firecrawl tools: explicit enable (MCP
  # tools default on, this documents intent) plus non-interactive allow.
  firecrawlTools = {
    firecrawl_search = true;
    firecrawl_scrape = true;
  };
  firecrawlPermission = {
    firecrawl_search = "allow";
    firecrawl_scrape = "allow";
  };
in
{
  config = lib.mkIf config.serverMode.developer {
    programs.opencode = {
      enable = true;
      package = pkgs.opencode;

      settings = {
        model = "deepseek/deepseek-v4-flash";
        default_agent = lib.mkIf onYifuwuqi "research";
        enabled_providers = [ "deepseek" ] ++ lib.mapAttrsToList (_: p: p.id) llamaProviders;
        agent = {
          plan = {
            variant = "max";
          }
          // lib.optionalAttrs onYifuwuqi {
            tools = firecrawlTools;
            permission = firecrawlPermission;
          };
          # build keeps its default toolset and gains the firecrawl research
          # tools; research additionally locks out everything else.
          build = lib.mkIf onYifuwuqi {
            tools = firecrawlTools;
            permission = firecrawlPermission;
          };
          research = lib.mkIf onYifuwuqi {
            description = "Current web research through local SearXNG search and Firecrawl scrape";
            mode = "primary";
            # Served by the Vulkan llama-server router (ROCm on the Ryzen 680M
            # APU corrupts prompts beyond ~4k tokens; Vulkan does not).
            model = "local/gemma-4-12b";
            temperature = 0.2;

            # Gate via tools only. Do not set permission."*" = "deny" here:
            # OpenCode last-match can let that blanket deny win over
            # firecrawl_* allows when rules are merged.
            # Search + scrape, both verified e2e (2026-11-17, via
            # packages/firecrawl-mcp; search against SearXNG, scrape against
            # the self-hosted instance).
            tools = firecrawlTools // {
              "*" = false;
            };
            permission = firecrawlPermission;
          };
        };
        provider = {
          deepseek.options.apiKey = "{file:/run/secrets/tokens/deepseek}";
        }
        // lib.mapAttrs' (
          host: p:
          lib.nameValuePair p.id {
            inherit (p) name;
            npm = "@ai-sdk/openai-compatible";
            options.baseURL = "http://${
              if hostName == host then "127.0.0.1" else hosts.${host}.network.vpn.ipv4.host
            }:${toString hosts.${host}.services.llama-cpp.port}/v1";
            models = ai.opencodeModelsForHost host;
          }
        ) llamaProviders;

        # Own zero-dependency MCP server (packages/firecrawl-mcp):
        # natively named tools search/scrape -> OpenCode registers the canonical
        # firecrawl_search / firecrawl_scrape, with small whitelisted schemas.
        # search queries the local SearXNG JSON API 1:1 (categories, engines,
        # language, time_range, pageno, safesearch) — Firecrawl's searxng
        # adapter drops tbs and pins categories via env, so it cannot serve
        # those; scrape stays on the Firecrawl API.
        # Registered only on yifuwuqi: the Firecrawl API is localhost-only
        # there; remote hosts reach it by ssh.
        mcp.firecrawl = lib.mkIf onYifuwuqi {
          type = "local";
          command = [ "${firecrawl-mcp}/bin/firecrawl-mcp" ];
          environment = {
            FIRECRAWL_API_URL = "http://localhost:${toString hosts.yifuwuqi.services.firecrawl.port}";
            SEARXNG_URL = "http://localhost:${toString hosts.yifuwuqi.services.searxng.port}";
          };
        };

        permission = {
          webfetch = "allow";
          websearch = "allow";
          question = "allow";
          task = "ask";
          firecrawl_search = "allow";
          firecrawl_scrape = "allow";

          # Raw remote-access binaries are denied outright; the only sanctioned
          # lane is `ai-ssh <host> <command>` (read-only gate, server-enforced).
          # The repo rule prefixes shell commands with `rtk`, so that form is
          # denied too. Anything not listed here keeps the default (ask).
          # No overlapping patterns => no order dependence.
          bash = {
            "ssh*" = "deny";
            "scp*" = "deny";
            "sshfs*" = "deny";
            "mosh*" = "deny";
            "rtk ssh*" = "deny";
            "rsync*" = "deny";
            "sudo*" = "deny";
            "sops*" = "deny";
            "nixos-rebuild switch*" = "deny";
            "nixos-rebuild boot*" = "deny";
            "nixos-rebuild test*" = "deny";
            "nix switch*" = "deny";
            "ai-ssh*" = "allow";
          };
        };
      };
    };
  };
}
