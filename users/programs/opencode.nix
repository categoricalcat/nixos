{
  pkgs,
  lib,
  osConfig ? null,
  ...
}:
let
  inherit (import ../../modules/services/ai/models.nix { inherit lib; }) opencodeModelsForHost;
  inherit (import ../../modules/addresses.nix) hosts;
  hostName = if osConfig == null then null else osConfig.networking.hostName;
  # Firecrawl's API listens on yifuwuqi's localhost only, so the MCP (declared
  # in users/home/mcp.nix via programs.mcp) and the research agent exist there
  # alone; other hosts keep only the built-in agents.
  onYifuwuqi = hostName == "yifuwuqi";

  # yifuwuqi's router listens on loopback only, so only yifuwuqi can reach it.
  llamaProviders = lib.filterAttrs (host: _: host != "yifuwuqi" || onYifuwuqi) {
    yifuwuqi = {
      id = "local";
      name = "Local (yifuwuqi)";
    };
    yitaishi = {
      id = "yitaishi";
      name = "Workstation (yitaishi)";
    };
  };

  rule = action: resource: effect: { inherit action resource effect; };
  allow = action: resource: rule action resource "allow";
  deny = action: resource: rule action resource "deny";
  # Scoped to build and plan only; putting this globally would override
  # explore/general's built-in `subagent * deny`.
  subagentAsk = [ (rule "subagent" "*" "ask") ];
in
{
  config = {
    programs.opencode = {
      enable = true;
      package = pkgs.opencode;
      # Pulls the shared firecrawl MCP server from programs.mcp (users/home/mcp.nix)
      # on yifuwuqi without duplicating its store path or endpoint URLs.
      enableMcpIntegration = true;
      # Fails the build when a key no longer exists in the OpenCode 2 schema
      # (`contextWindow`, `tools`, `variant`, … were all silently dropped in
      # the v1 → v2 migration and only surfaced at runtime).
      validateFiles.config = true;

      settings = {
        model = "deepseek/deepseek-flash";
        # Research is read-only/web-only and cannot edit or run shell commands,
        # so it is opt-in rather than the default for every session.
        default_agent = "build";
        # Built-in websearch ships Exa (mcp.exa.ai); disable it on all hosts
        # (yifuwuqi serves local SearXNG via firecrawl_search).
        websearch = false;

        # Ordered policies: `tool.use` runs as a post-evaluation hook in
        # Permission.evaluate across every agent and after saved approvals, so
        # invariant secret/shell/websearch denies cannot be shadowed by agent
        # allows or leaked into locked-down built-in agents (summary/title).
        policies = [
          (deny "provider.use" "*")
          (deny "websearch.use" "*")
          (deny "tool.use" "websearch:*")
        ]
        ++ lib.map (id: allow "provider.use" id) (
          [ "deepseek" ] ++ lib.mapAttrsToList (_: p: p.id) llamaProviders
        )
        # OpenCode 2's wildcard matcher turns `*` into `.*` with no globstar
        # semantics, and FileAccess resolves interior paths relative without a
        # leading `/` while directory reads have no trailing `/`. The 4 forms
        # match exact dirs and descendants both relative and absolute (so
        # `*/secrets*` also covers `/run/secrets`) without blocking
        # `docs/src/services/secrets.md` or `ai-ssh.md`. `external_directory`
        # additionally gates grep/glob/shell outside the workspace.
        ++ lib.map (p: deny "tool.use" "${p.action}:${p.pattern}") (
          lib.cartesianProduct {
            action = [
              "read"
              "edit"
              "external_directory"
            ];
            pattern =
              lib.concatMap
                (dir: [
                  dir
                  "${dir}/*"
                  "*/${dir}"
                  "*/${dir}/*"
                ])
                [
                  "secrets"
                  "persist/keys"
                  ".ssh"
                ];
          }
        )
        # Remote-access and privileged binaries are denied outright; `ai-ssh`
        # is the only sanctioned remote lane (read-only, server-enforced).
        # `rtk ssh*` is denied too because `rtk` is installed in the user
        # environment (users/home/common.nix).
        ++ lib.map (cmd: deny "tool.use" "shell:${cmd}") [
          "mosh*"
          "nix switch*"
          "nixos-rebuild boot*"
          "nixos-rebuild switch*"
          "nixos-rebuild test*"
          "rsync*"
          "rtk ssh*"
          "scp*"
          "sops*"
          "ssh*"
          "sshfs*"
          "sudo*"
        ];

        # Plain values only: settings is a JSON option, so host-conditional
        # agents use `lib.optionalAttrs` rather than `mkIf`. `build` and `plan`
        # inherit built-in `* * allow` (covering MCP `firecrawl_*` on yifuwuqi)
        # and only add `subagent * ask`; omitting top-level `permissions` keeps
        # `summary`, `title`, `explore`, and `general` at their built-in bounds.
        agents = {
          build.permissions = subagentAsk;
          # `#max` selects the model variant; v2 dropped the agent-level `variant` key.
          plan = {
            model = "deepseek/deepseek-flash#max";
            permissions = subagentAsk;
          };
        }
        // lib.optionalAttrs onYifuwuqi {
          research = {
            description = "Current web research through local SearXNG search and Firecrawl scrape/map";
            mode = "primary";
            # Served by the Vulkan llama-server router (ROCm on the Ryzen 680M
            # APU corrupts prompts beyond ~4k tokens; Vulkan does not).
            model = "local/deepseek-v4-pro-qwen3.5-9b-uncensored";
            request.body.temperature = 0.2;
            # OpenCode 2 evaluates agent permissions last-match-wins, so the
            # blanket deny comes first and explicit allows follow; invariant
            # secret denies apply globally via `policies` (`tool.use`).
            permissions = [
              (deny "*" "*")
            ]
            ++ lib.map (action: allow action "*") [
              "read"
              "grep"
              "glob"
              "skill"
              "webfetch"
              "question"
              "firecrawl_map"
              "firecrawl_scrape"
              "firecrawl_search"
            ]
            ++ [
              (rule "read" "*.env" "ask")
              (rule "read" "*.env.*" "ask")
              (allow "read" "*.env.example")
            ];
          };
        };

        providers = {
          deepseek.settings.apiKey = "{file:/run/secrets/tokens/deepseek}";
        }
        // lib.mapAttrs' (
          host: p:
          lib.nameValuePair p.id {
            inherit (p) name;
            package = "@ai-sdk/openai-compatible";
            settings.baseURL = "http://${
              if hostName == host then "127.0.0.1" else hosts.${host}.network.vpn.ipv4.host
            }:${toString hosts.${host}.services.llama-cpp.port}/v1";
            models = opencodeModelsForHost host;
          }
        ) llamaProviders;
      };
    };
  };
}
