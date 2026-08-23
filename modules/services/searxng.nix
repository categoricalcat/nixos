{
  pkgs,
  allAddresses,
  config,
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

  # The shared valkey's unix socket is owned redis:redis mode 660; searx needs
  # group access to use it (rate-limiter keys live on logical db 1).
  users.users.searx.extraGroups = [ "redis" ];

  services.searx = {
    enable = true;
    package = pkgs.searxng;
    environmentFile = secretEnv;

    settings = {
      # Shared valkey on yifuwuqi (also backing unbound's cachedb); rate
      # limiter keys live in logical db 1, separate from the DNS cache.
      valkey.url = "unix://${config.services.redis.servers."".unixSocket}?db=1";

      general = {
        instance_name = "yi search";
        debug = false;
        privacypolicy_url = false;
        donation_url = false;
        contact_url = false;
        enable_metrics = false;
      };

      server = {
        # Public access still goes through nginx on yirukou, but the backend
        # must be reachable from the router over LAN and directly via Tailscale.
        bind_address = "0.0.0.0";
        port = allAddresses.hosts.${config.networking.hostName}.services.searxng.port;
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
        # JSON enabled for scripted clients.
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
        # Route all outbound requests through Tor's SOCKS proxy.
        # `socks5h` resolves DNS through Tor too, which is essential for
        # bypassing DNS-based censorship. This lets us re-enable engines
        # that were previously blocked/rate-limited from this server IP.
        #
        # Intentionally NOT setting `using_tor_proxy = true`: that flag
        # makes SearXNG perform a real Tor handshake at startup and refuse
        # to start otherwise. systemd marks `tor.service` active the moment
        # the daemon launches, NOT when bootstrap (consensus + circuit
        # build) completes, so SearXNG would race Tor on cold boot and
        # crash with "Invalid network configuration". Instead we order
        # `searx.service` after `wait-for-tor.service` (below), which polls
        # until SOCKS actually proxies HTTPS.
        #
        # `proxies` is the httpx pattern map -- the awkward attribute name
        # `all://` must be quoted because of `:` and `//`. Value is a list
        # so httpx round-robins between proxies if more are added later.
        proxies = {
          "all://" = [ "socks5h://127.0.0.1:9050" ];
        };
        # Bumped from 5/15 so slower survivors (Bing, Qwant, Mojeek) get a
        # chance to respond when faster engines (Brave) hit a 429 burst.
        # Tor adds ~1-3s, so the timeouts are slightly elevated.
        request_timeout = 8.0;
        max_request_timeout = 25.0;
        pool_connections = 100;
        pool_maxsize = 15;
        enable_http2 = true;
      };

      # Engine pool: now routed through Tor, so engines that were blocked /
      # rate-limited from this IP (DDG, Startpage) are re-enabled.  Google
      # stays disabled — it still hands out CAPTCHAs to Tor exit nodes.
      # Mojeek remains as a privacy-first fallback with its own crawl index.
      # Mullvad Leta is intentionally NOT enabled: its upstream engine
      # requires SearXNG to run behind a Mullvad VPN connection, which we do
      # not.
      engines = [
        {
          name = "duckduckgo";
          engine = "duckduckgo";
          shortcut = "ddg";
          categories = "general";
          disabled = false;
        }
        {
          name = "mojeek";
          disabled = false;
          shortcut = "mjk";
          categories = "general";
        }
        {
          name = "google scholar";
          engine = "google_scholar";
          shortcut = "gs";
          categories = "science";
          disabled = false;
        }
        {
          name = "arxiv";
          engine = "arxiv";
          shortcut = "ar";
          categories = "science";
          disabled = false;
        }
        {
          name = "google";
          disabled = true;
        }
      ];

      enabled_plugins = [
        "Basic Calculator"
        "Hash plugin"
        "Open Access DOI rewrite"
        "Unit converter plugin"
        # "Tracker URL remover" disabled - upstream issue searxng/searxng#4951:
        # the per-result SQLite cache at /tmp/sxng_cache_DATA_CACHE.db locks
        # itself readonly under our hardened systemd unit and spams every
        # query with sqlite3.OperationalError. Scripted search results don't
        # need utm_* stripping anyway.
      ];
    };
  };

  systemd.services = {
    searx-secret-init = {
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

    # Block dependent services until Tor's SOCKS port actually proxies
    # outbound traffic (i.e., bootstrap is done and a circuit is built).
    # systemd alone considers `tor.service` active the moment the daemon
    # launches, which is too early -- a TCP connect to 9050 succeeds long
    # before Tor can route a request, so SearXNG's own startup probe
    # (when `using_tor_proxy = true` is set) crashes with "Invalid network
    # configuration". The full HTTPS-through-SOCKS check below covers both
    # reachability AND bootstrap.
    wait-for-tor = {
      description = "Wait for Tor SOCKS to be usable";
      after = [
        "tor.service"
        "network-online.target"
      ];
      wants = [
        "tor.service"
        "network-online.target"
      ];
      before = [ "searx.service" ];
      wantedBy = [ "searx.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "180s";
        ExecStart = pkgs.writeShellScript "wait-for-tor" ''
          set -eu
          attempts=25
          for i in $(seq 1 $attempts); do
            if ${pkgs.curl}/bin/curl --silent --fail --max-time 15 \
                --socks5-hostname 127.0.0.1:9050 \
                https://check.torproject.org/api/ip > /dev/null 2>&1; then
              echo "Tor SOCKS ready after $i attempt(s)"
              exit 0
            fi
            sleep 5
          done
          echo "Tor SOCKS not ready after $attempts attempts" >&2
          exit 1
        '';
      };
    };

    # Wait for live network + a bootstrapped Tor before contacting upstream
    # search engines. Ordering against searx-secret-init is handled by that
    # unit's `before`/`wantedBy` above. `tor.service` is pulled in
    # transitively via `wait-for-tor.service`, so it's not listed directly
    # here. SyslogLevel=err ensures SearXNG's own errors are clearly
    # distinguished in the journal.
    searx = {
      wants = [
        "network-online.target"
        "wait-for-tor.service"
        "redis.service"
      ];
      after = [
        "network-online.target"
        "wait-for-tor.service"
        "redis.service"
      ];
      serviceConfig.SyslogLevel = "err";
    };
  };
}
