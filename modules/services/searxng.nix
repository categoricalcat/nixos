{
  pkgs,
  ...
}:

let
  secretDir = "/run/searx-secret";
  secretEnv = "${secretDir}/env";
in
{
  # Generate a fresh runtime secret before each start. Rotating it is acceptable
  # here because it only signs limiter / image-proxy tokens.
  #
  # The upstream NixOS searx module wires `services.searx.environmentFile` into
  # both `searx-init.service` (envsubst) and `searx.service`, so this unit must
  # finish before either of them, otherwise EnvironmentFile= fails on first
  # boot and `searx-init` never writes /run/searx/settings.yml.
  systemd.services.searx-secret-init = {
    description = "Generate runtime SearXNG secret_key";
    wantedBy = [
      "searx-init.service"
      "searx.service"
    ];
    before = [
      "searx-init.service"
      "searx.service"
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      install -d -m 0750 -o root -g searx ${secretDir}
      umask 077
      printf 'SEARXNG_SECRET=%s\n' \
        "$(${pkgs.openssl}/bin/openssl rand -hex 32)" \
        > ${secretEnv}
      chown root:searx ${secretEnv}
      chmod 0440 ${secretEnv}
    '';
  };

  services.searx = {
    enable = true;
    package = pkgs.searxng;
    redisCreateLocally = true;
    environmentFile = secretEnv;

    settings = {
      general = {
        instance_name = "yi search";
        debug = false;
        privacypolicy_url = false;
        donation_url = false;
        contact_url = false;
        enable_metrics = false;
      };

      server = {
        # Bind on all host addresses so the Podman sidecar can reach SearXNG
        # through the host LAN IP while local consumers can keep using loopback.
        bind_address = "0.0.0.0";
        port = 8888;
        # `searx-init.service` runs envsubst over this YAML and loads
        # `EnvironmentFile=/run/searx-secret/env`, so `$SEARXNG_SECRET` here is
        # replaced with the runtime-generated value before SearXNG starts.
        secret_key = "$SEARXNG_SECRET";
        base_url = "https://search.fufu.land/";
        image_proxy = true;
        limiter = false;
        public_instance = false;
        method = "GET";
      };

      search = {
        safe_search = 0;
        autocomplete = "duckduckgo";
        autocomplete_min = 2;
        # JSON enabled for LibreChat's webSearch and any MCP / scripted clients.
        formats = [
          "html"
          "json"
        ];
      };

      ui = {
        default_theme = "simple";
        theme_args.simple_style = "auto";
        infinite_scroll = true;
        query_in_title = true;
        center_alignment = true;
      };

      outgoing = {
        request_timeout = 5.0;
        max_request_timeout = 15.0;
        pool_connections = 100;
        pool_maxsize = 15;
        enable_http2 = true;
      };

      enabled_plugins = [
        "Basic Calculator"
        "Hash plugin"
        "Open Access DOI rewrite"
        "Unit converter plugin"
        "Tracker URL remover"
      ];
    };
  };

  # Wait for live network before contacting upstream search engines. Ordering
  # against searx-secret-init is handled by that unit's `before`/`wantedBy`
  # above. SyslogLevel=err lifts captured stderr above the host's
  # MaxLevelStore=notice journald cap so SearXNG's own errors survive to disk.
  systemd.services.searx = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig.SyslogLevel = "err";
  };
}
