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
        default_agent = "research";
        enabled_providers = [ "deepseek" ] ++ lib.mapAttrsToList (_: p: p.id) llamaProviders;
        agent = {
          plan.variant = "max";
          research = {
            description = "Current web research through self-hosted Firecrawl";
            mode = "primary";
            # Served by the Vulkan llama-server router on each host (ROCm on the
            # Ryzen 680M APU corrupts prompts beyond ~4k tokens; Vulkan does not).
            model = if hostName == "yifuwuqi" then "local/gemma-4-12b" else "yitaishi/qwen3.8-27b";
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
              FIRECRAWL_API_URL = "http://localhost:${toString hosts.yifuwuqi.services.firecrawl.port}";
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
