{
  lib,
  pkgs,
  allAddresses,
  config,
  ...
}:

let
  secretDir = "/run/searx-secret";
  secretEnv = "${secretDir}/env";
  searxng = allAddresses.hosts.${config.networking.hostName}.services.searxng;
in
{
  # Generate a fresh runtime secret before each start. Rotating it is acceptable
  # here because it only signs limiter / image-proxy tokens.
  #
  # The upstream NixOS searx module wires `services.searx.environmentFile` into
  # both `searx-init.service` (envsubst) and `searx.service`, so this unit must
  # finish before either of them, otherwise EnvironmentFile= fails on first
  # boot and `searx-init` never writes /run/searx/settings.yml.

  # The local valkey's unix socket is owned redis:redis mode 660; searx needs
  # group access to use it (rate-limiter keys live on logical db 1).
  users.users.searx.extraGroups = [ "redis" ];

  services.searx = {
    enable = true;
    # Patch three upstream Tor/curl_cffi bugs:
    # 1. duckduckgo sets Content-Type explicitly on POST; curl_cffi then emits
    #    Content-Type before Content-Length, triggering DuckDuckGo HTTP 202
    #    CAPTCHA on every request (removing it lets curl_cffi emit standard
    #    Content-Length -> Content-Type order).
    # 2. duckduckgo_extra.fetch_vqd hardcodes timeout=2, failing >50% over Tor.
    # 3. bing_news passes empty HTTP 200 bodies to lxml, failing with parsing error.
    package = pkgs.searxng.overridePythonAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace searx/engines/duckduckgo.py \
          --replace-fail '    params["headers"]["Content-Type"] = "application/x-www-form-urlencoded"' ""
        substituteInPlace searx/engines/duckduckgo_extra.py \
          --replace-fail $'        headers=params["headers"],\n        timeout=2,' '        headers=params["headers"],'
        substituteInPlace searx/engines/bing_news.py \
          --replace-fail '    dom = resp.html()' $'    if not resp.text.strip():\n        return results\n\n    dom = resp.html()'
      '';
    });
    environmentFile = secretEnv;

    settings = {
      # Rate-limiter keys live in logical db 1 of the host-local valkey.
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
        # Firecrawl reaches this from its container via host.containers.internal
        # (the podman bridge gateway, not loopback), so it cannot bind loopback.
        # The firewall scopes exposure: eno1 allows only the gateway ingress and
        # Loki; tailscale0 has its own port list; containers get an explicit rule.
        bind_address = "0.0.0.0";
        inherit (searxng) port;
        # `searx-init.service` runs envsubst over this YAML and loads
        # `EnvironmentFile=/run/searx-secret/env`, so `$SEARXNG_SECRET` here is
        # replaced with the runtime-generated value before SearXNG starts.
        secret_key = "$SEARXNG_SECRET";
        base_url = "https://${searxng.domain}/";
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
        # Behind Tor, a timeout or CAPTCHA/403/429 belongs to one exit circuit,
        # not the host IP. Disable transient fail bans so the next request can
        # immediately use a fresh pool circuit, and keep exhausted-retry
        # suspension windows short (upstream defaults: Captcha 3600s, CF 15d).
        ban_time_on_fail = 0;
        max_ban_time_on_fail = 0;
        suspended_times = {
          SearxEngineAccessDenied = 30;
          SearxEngineCaptcha = 60;
          SearxEngineTooManyRequests = 30;
          cf_SearxEngineCaptcha = 60;
          cf_SearxEngineAccessDenied = 60;
          recaptcha_SearxEngineCaptcha = 60;
        };
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
        # crash with "Invalid network configuration". Leaving it off lets
        # SearXNG boot without blocking multi-user.target while Tor finishes
        # bootstrapping.
        #
        # `proxies` is the curl_cffi pattern map -- the awkward attribute name
        # `all://` must be quoted because of `:` and `//`. Four distinct dummy
        # credentials trigger Tor's default `IsolateSOCKSAuth`, giving SearXNG's
        # round-robin cycle four independent exit circuits per engine.
        proxies = {
          "all://" = map (n: "socks5h://pool${toString n}:x@127.0.0.1:9050") (lib.range 1 4);
        };
        # 10s covers normal Tor RTT (0.5-5s) while failing stalled circuits fast
        # enough for firecrawl-mcp's single retry to finish inside its timeout.
        request_timeout = 10.0;
        max_request_timeout = 15.0;
        retries = 1;
        pool_connections = 100;
        pool_maxsize = 15;
        enable_http2 = true;
        # Dedicated named network per engine (referenced by string below)
        # decouples brave.news from brave's SuspendedStatus, rotates across all
        # 4 Tor circuits on 403/429 (plus 202 for DuckDuckGo's CAPTCHA challenge)
        # within one search, and avoids SearXNG's settings_loader.update_dict
        # TypeError when overriding brave.news's upstream string `network: brave`
        # with a dict.
        networks =
          lib.genAttrs
            [
              "brave-tor"
              "brave.news-tor"
              "duckduckgo-tor"
              "duckduckgo news-tor"
            ]
            (name: {
              retries = 3;
              retry_on_http_error = [
                403
                429
              ]
              ++ lib.optional (lib.hasPrefix "duckduckgo" name) 202;
            });
      };

      # Engine pool: routed through Tor, using upstream defaults (Brave,
      # DuckDuckGo, Bing News, etc.) with dead/blocked entries pruned. Google
      # stays disabled — it hands out CAPTCHAs to Tor exit nodes. Mojeek and
      # Startpage stay inactive per upstream (CPU-heavy PoW CAPTCHAs). Reuters
      # (HTTP 401) and Wikidata (HTTP 403 SPARQL + hardcoded 3s timeout) fail
      # over Tor. Radio Browser performs unproxied clearnet DNS during init()
      # and fails offline registration. Ahmia and Torch require
      # `using_tor_proxy = true` and fail registration without it. Mullvad Leta
      # requires a Mullvad VPN.
      engines = [
        {
          name = "brave";
          network = "brave-tor";
        }
        {
          name = "brave.news";
          network = "brave.news-tor";
        }
        {
          name = "duckduckgo";
          engine = "duckduckgo";
          shortcut = "ddg";
          categories = "general";
          disabled = false;
          network = "duckduckgo-tor";
        }
        {
          name = "duckduckgo news";
          network = "duckduckgo news-tor";
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
          name = "reuters";
          disabled = true;
        }
        {
          name = "radio browser";
          disabled = true;
        }
        {
          name = "wikidata";
          disabled = true;
        }
        {
          name = "ahmia";
          inactive = true;
        }
        {
          name = "torch";
          inactive = true;
        }
        {
          name = "google";
          disabled = true;
        }
        # Disabling by name covers exact names only; the bumped default pool
        # grew google cse/news/videos/cse images entries that the "google"
        # entry above no longer covers — and google cse was serving general
        # results, against the "Google stays disabled" intent.
        {
          name = "google cse";
          disabled = true;
        }
        {
          name = "google cse images";
          disabled = true;
        }
        {
          name = "google news";
          disabled = true;
        }
        {
          name = "google videos";
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

    # Ordering against searx-secret-init is handled by that unit's
    # `before`/`wantedBy` above. `using_tor_proxy` is off, so SearXNG starts
    # cleanly as soon as network-online, tor, and local valkey are up without
    # waiting on an external Tor circuit probe (Type=simple adds ~0s to boot).
    # SyslogLevel=err ensures SearXNG's own errors are clearly distinguished in
    # the journal.
    searx = {
      wants = [
        "network-online.target"
        "tor.service"
        "redis.service"
      ];
      after = [
        "network-online.target"
        "tor.service"
        "redis.service"
      ];
      # Upstream NixOS searx.nix sets restartTriggers only on uwsgi, not the
      # non-uwsgi unit; trigger a restart whenever settings.yml changes.
      restartTriggers = [
        (builtins.toJSON config.services.searx.settings)
      ];
      serviceConfig.SyslogLevel = "err";
    };
  };
}
