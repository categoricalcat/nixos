{
  pkgs,
  ...
}:

let
  secretDir = "/var/lib/searx-secret";
  secretEnv = "${secretDir}/env";
in
{
  systemd.tmpfiles.rules = [
    "d ${secretDir} 0750 searx searx -"
  ];

  # Generates SEARXNG_SECRET on first boot. The key only signs limiter / image-proxy
  # tokens, so a stateful local file (instead of sops) is enough behind nginx + htpasswd.
  systemd.services.searx-secret-init = {
    description = "Generate SearXNG secret_key on first boot";
    wantedBy = [ "searx.service" ];
    before = [ "searx.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -s ${secretEnv} ]; then
        umask 077
        printf 'SEARXNG_SECRET=%s\n' \
          "$(${pkgs.openssl}/bin/openssl rand -hex 32)" \
          > ${secretEnv}
        chown searx:searx ${secretEnv}
        chmod 0440 ${secretEnv}
      fi
    '';
  };

  services.searx = {
    enable = true;
    package = pkgs.searxng;
    redisCreateLocally = true;
    environmentFile = secretEnv;

    settings = {
      general = {
        instance_name = "fufu search";
        debug = false;
        privacypolicy_url = false;
        donation_url = false;
        contact_url = false;
        enable_metrics = false;
      };

      server = {
        bind_address = "127.0.0.1";
        port = 8888;
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
        # JSON is required so Open WebUI / AgenticSeek can consume the API.
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

  systemd.services.searx = {
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "searx-secret-init.service"
    ];
    requires = [ "searx-secret-init.service" ];
  };
}
