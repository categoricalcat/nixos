{
  addresses,
  allAddresses,
  config,
  lib,
  pkgs,
  ...
}:

let
  yirukouLan = allAddresses.hosts.yirukou.network.lan.ipv4.host;

  mkRewrite =
    host: alias:
    let
      answer = lib.attrByPath alias.path null host;
    in
    lib.optional (answer != null) {
      domain = "${host.hostName}.${alias.suffix}";
      inherit answer;
      enabled = true;
    };
  hostRewrites = lib.concatMap (
    host: lib.concatMap (alias: mkRewrite host alias) allAddresses.aliases
  ) (builtins.attrValues allAddresses.hosts);
in
{
  # https://github.com/AdguardTeam/AdGuardHome/wiki/Configuration#configuration-file
  services.adguardhome = {
    enable = true;
    package = pkgs.adguardhome;
    host = "0.0.0.0";
    port = allAddresses.hosts.${config.networking.hostName}.services.adguardhome.port;
    mutableSettings = false;
    settings = {

      http = {
        address = "0.0.0.0:${
          toString allAddresses.hosts.${config.networking.hostName}.services.adguardhome.port
        }";
        session_ttl = "12h";
      };

      dns = {
        # Wildcard so plain DNS / DoT / DoQ / DoH stay reachable on the dynamic fallback WAN IP.
        # Plain DNS on port 53 is gated to internal interfaces by the host firewall.
        bind_hosts = allAddresses.hosts.${config.networking.hostName}.services.adguardhome.dnsBindHosts;

        # Forward everything to local Unbound
        upstream_dns = [ "127.0.0.1:5335" ];

        # load_balance: weighted random algorithm to select the best upstream server.
        # parallel: Parallel queries to all configured upstream servers to speed up resolving.
        # fastest_addr: It finds an IP address with the lowest latency and returns this IP address in DNS response.
        upstream_mode = "parallel";

        bootstrap_prefer_ipv6 = false;
        bootstrap_dns = [
          "127.0.0.1:5335"
        ];
        # fallback_dns = [];
        local_ptr_upstreams = [ "127.0.0.1:5335" ];

        edns_client_subnet = {
          enabled = true;
          use_custom = false;
        };
        ecs_use_subnet_opt = true;
        ratelimit = 0; # no per-client rate limit

        # Edge quick cache (AGH) in front of the slow-but-huge unbound+valkey
        # resolver. AGH answers the hot working set from RAM in ~sub-ms; the
        # cache is keyed per (qname,qtype,DO).
        cache_enabled = true;
        cache_size = 67108864; # 64 MiB (default is 4 MiB)
        # cache_ttl_max caps stored AND served TTLs at 5m (dnsproxy clamps
        # every upstream response via setMinMaxTTL), so a hot name re-queries
        # unbound ~every 300s and lands in prefetch's last-10%-of-TTL window
        # (>= 360s on a cache-min-ttl=1h record). unbound (>=1h / <=7d) and
        # valkey (EX = clamped TTL + 7d) keep the long copy; clients see at
        # most 5m of edge staleness. cache_ttl_min stays 0 (unset): unbound
        # already floors TTLs at >= 1h.
        cache_ttl_max = 300;
        # Optimistic refresh: on expiry AGH serves the stale answer (with TTL
        # cache_optimistic_answer_ttl) and re-resolves in the background on
        # EVERY expired hit, so client latency stays ~0. max_age is NOT a
        # refresh cadence: it only bounds how long a *failed* refresh may
        # still be served past expiry (only matters when local unbound is
        # down). 1h instead of the 12h default -- this is a short edge cache.
        cache_optimistic = true;
        cache_optimistic_answer_ttl = "30s";
        cache_optimistic_max_age = "1h";
        enable_dnssec = true;
        ipv6_disabled = false;
        max_goroutines = 1000;
        upstream_timeout = "2s";
        serve_http3 = true;
      };

      filtering = {
        blocking_mode = "custom_ip";
        blocking_ipv4 = addresses.network.sinkhole.ipv4.host;
        blocking_ipv6 = addresses.network.sinkhole.ipv6.host;
        blocked_response_ttl = 60;

        rewrites = [
          {
            domain = "smb.fufu.land";
            answer = allAddresses.hosts.yifuwuqi.network.lan.ipv4.host;
            enabled = true;
          }
          {
            domain = "*.fufu.land";
            answer = yirukouLan;
            enabled = true;
          }
          {
            domain = "fufu.land";
            answer = yirukouLan;
            enabled = true;
          }
        ]
        ++ hostRewrites;
      };

      filters = [
        {
          id = 1;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
          name = "AdGuard Home Default Filter";
          enabled = false;
        }
        {
          id = 2;
          url = "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.txt";
          name = "Hagezi Multi PRO";
          enabled = false;
        }
        {
          id = 3;
          url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.plus.txt";
          name = "Hagezi Multi PRO++";
          enabled = true;
        }
        {
          id = 4;
          url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.txt";
          name = "Hagezi TIF";
          enabled = true;
        }
      ];

      user_rules = [ "||api.miwifi.com^" ];

      tls = lib.mkIf (config.security.acme.certs ? "fufu.land") {
        enabled = true;
        server_name = "dns.fufu.land";
        port_https = 3443;
        port_dns_over_tls = 853;
        port_dns_over_quic = 853;

        # Use the centralized ACME wildcard certificates
        certificate_path = "/var/lib/acme/fufu.land/fullchain.pem";
        private_key_path = "/var/lib/acme/fufu.land/key.pem";

        # Enable all secure DNS protocols
        serve_plain_dns = true;
        allow_unencrypted_doh = true;
        strict_sni_check = false;
      };

      log = {
        enabled = true;
        file = "";
      };

      querylog = {
        enabled = true;
        file_enabled = true;
        interval = "720h";
        size_memory = 10485760; # 10MiB
      };

      statistics = {
        enabled = true;
        interval = "720h";
      };
    };
  };

  systemd.services.adguardhome = {
    wants = [
      "network-online.target"
      "unbound.service"
    ];
    after = [
      "network-online.target"
      "unbound.service"
    ]
    ++ (lib.optional config.services.tailscale.enable "tailscaled.service")
    ++ (lib.optional config.services.netbird.enable "netbird.service");

    environment = {
      GOMEMLIMIT = "2560MiB";
    };
  };
}
