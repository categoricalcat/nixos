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
  # Firecrawl's API listens on yifuwuqi's localhost only, so the MCP (declared
  # in users/home/mcp.nix via programs.mcp) and the research agent exist there
  # alone; other hosts use the built-in default agent and reach Firecrawl by ssh.
  onYifuwuqi = hostName == "yifuwuqi";

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
  # tools default on, this documents intent) plus non-interactive allow. One
  # name list derives both sets; the top-level permission block reuses the
  # permission set instead of repeating the names.
  firecrawlToolNames = [
    "firecrawl_map"
    "firecrawl_scrape"
    "firecrawl_search"
  ];
  firecrawlTools = lib.genAttrs firecrawlToolNames (_: true);
  firecrawlPermission = lib.genAttrs firecrawlToolNames (_: "allow");
in
{
  config = lib.mkIf config.serverMode.developer {
    programs.opencode = {
      enable = true;
      package = pkgs.opencode;
      # Pulls the shared firecrawl MCP server from programs.mcp (users/home/mcp.nix)
      # on yifuwuqi without duplicating its store path or endpoint URLs.
      enableMcpIntegration = true;

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
            description = "Current web research through local SearXNG search and Firecrawl scrape/map";
            mode = "primary";
            # Served by the Vulkan llama-server router (ROCm on the Ryzen 680M
            # APU corrupts prompts beyond ~4k tokens; Vulkan does not).
            model = "local/gemma-4-12b";
            temperature = 0.2;

            # Gate via tools only. Do not set permission."*" = "deny" here:
            # OpenCode last-match can let that blanket deny win over
            # firecrawl_* allows when rules are merged.
            # Search + scrape verified e2e (2026-11-17, via
            # packages/firecrawl-mcp; search against SearXNG, scrape against
            # the self-hosted instance); map added 2026-11-20, same MCP.
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

        # Own zero-dependency MCP server (packages/firecrawl-mcp), declared once
        # in users/home/mcp.nix (programs.mcp.servers.firecrawl) and pulled in
        # via enableMcpIntegration on yifuwuqi: natively named tools
        # search/scrape/map -> OpenCode registers the canonical
        # firecrawl_search / firecrawl_scrape / firecrawl_map, with small flat
        # schemas. search queries the local SearXNG JSON API 1:1 and lossless
        # (categories, engines, language, time_range, pageno, safesearch,
        # timeout_limit; category names come from the instance's own GET /config
        # listing) and returns SearXNG's whole JSON answer verbatim; scrape and
        # map stay on the Firecrawl API.

        permission = {
          webfetch = "allow";
          websearch = "allow";
          question = "allow";
          task = "ask";

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
        }
        // firecrawlPermission;
      };
    };
  };
}
