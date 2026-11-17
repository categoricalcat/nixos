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
          plan.variant = "max";
          research = lib.mkIf onYifuwuqi {
            description = "Current web research through self-hosted Firecrawl";
            mode = "primary";
            # Served by the Vulkan llama-server router (ROCm on the Ryzen 680M
            # APU corrupts prompts beyond ~4k tokens; Vulkan does not).
            model = "local/gemma-4-12b";
            temperature = 0.2;

            # Gate via tools only. Do not set permission."*" = "deny" here:
            # OpenCode last-match can let that blanket deny win over
            # firecrawl_* allows when rules are merged.
            # Search + scrape, both verified e2e against the self-hosted
            # instance (2026-11-16, via packages/firecrawl-mcp).
            tools = {
              "*" = false;
              firecrawl_search = true;
              firecrawl_scrape = true;
            };
            permission = {
              firecrawl_search = "allow";
              firecrawl_scrape = "allow";
            };
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
        # Registered only on yifuwuqi: the Firecrawl API is localhost-only
        # there; remote hosts reach it by ssh.
        mcp.firecrawl = lib.mkIf onYifuwuqi {
          type = "local";
          command = [ "${firecrawl-mcp}/bin/firecrawl-mcp" ];
          environment = {
            FIRECRAWL_API_URL = "http://localhost:${toString hosts.yifuwuqi.services.firecrawl.port}";
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
