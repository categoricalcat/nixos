{
  addresses,
  config,
  lib,
  ...
}:
{
  # https://github.com/AdguardTeam/AdGuardHome/wiki/Configuration#configuration-file
  services.adguardhome = {
    enable = true;
    host = "0.0.0.0";
    port = 3333;
    mutableSettings = false;
    settings = {

      http = {
        address = "0.0.0.0:3333";
        session_ttl = "12h";
      };

      dns = {
        bind_hosts = [
          "127.0.0.1"
          addresses.network.lan.ipv4.host
        ]
        ++ (lib.optional config.services.tailscale.enable addresses.network.tailscale.ipv4.host);
        #        ++ (lib.optional config.services.zerotierone.enable addresses.network.zerotier.ipv4.host);

        upstream_dns =
          addresses.dns.quad9
          ++ addresses.dns.adguard
          ++ addresses.dns.google
          ++ addresses.dns.cloudflare
          ++ addresses.dns.opendns
          ++ addresses.dns.nextdns
          ++ addresses.dns.freedns;

        # load_balance: weighted random algorithm to select the best upstream server.
        # parallel: Parallel queries to all configured upstream servers to speed up resolving.
        # fastest_addr: It finds an IP address with the lowest latency and returns this IP address in DNS response.
        upstream_mode = "parallel";

        bootstrap_prefer_ipv6 = true;
        bootstrap_dns = [
          "2620:fe::fe"
          "9.9.9.9"
        ];

        edns_client_subnet = {
          enabled = true;
          use_custom = false;
        };
        ecs_use_subnet_opt = true;
        ratelimit = 0; # no per-client rate limit
        enable_dnssec = true;
        ipv6_disabled = false;
        max_goroutines = 300;
        upstream_timeout = "4s";
        serve_http3 = true;

        cache_enabled = true;
        cache_size = 5000000;
        cache_optimistic = true;
        # Uncomment to make every blocked domain fail with NXDOMAIN globally.
        # blocking_mode = "nxdomain";
      };

      filtering = {
        rewrites = [
          {
            domain = "*.fufu.land";
            answer = addresses.network.lan.ipv4.host;
            enabled = true;
          }
          {
            domain = "fufu.land";
            answer = addresses.network.lan.ipv4.host;
            enabled = true;
          }
          {
            domain = "${addresses.hostName}.${addresses.dns.domain}";
            answer = addresses.network.tailscale.ipv4.host;
            enabled = true;
          }
          {
            domain = "wg.localto.net";
            answer = "192.168.0.42";
            enabled = true;
          }
          {
            domain = "${addresses.hostName}.lan";
            answer = addresses.network.lan.ipv4.host;
            enabled = true;
          }
          {
            domain = "${addresses.hostName}";
            answer = addresses.network.lan.ipv4.host;
            enabled = true;
          }
          {
            domain = "${addresses.hostName}.zero";
            answer = addresses.network.zerotier.ipv4.host;
            enabled = true;
          }
          {
            domain = "${addresses.hostName}.ts";
            answer = addresses.network.tailscale.ipv4.host;
            enabled = true;
          }
          {
            domain = "${addresses.hostName}.yun";
            answer = addresses.network.lan.ipv4.host;
            enabled = true;
          }
        ];
      };

      filters = [
        {
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
          name = "AdGuard Home Default Filter";
          enabled = true;
        }
        {
          url = "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.txt";
          name = "Hagezi Multi PRO";
          enabled = false;
        }
        {
          url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.plus.txt";
          name = "Hagezi Multi PRO++";
          enabled = true;
        }
        {
          url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.txt";
          name = "Hagezi TIF";
          enabled = true;
        }
      ];

      # Use targeted NXDOMAIN rules by default so blocked Microsoft telemetry hosts
      # fail at DNS instead of reaching local HTTPS and seeing the wrong cert.
      # Remove these rules if you switch to the global NXDOMAIN option above.
      user_rules = [
        "||mobile.events.data.microsoft.com^$dnsrewrite=NXDOMAIN"
        "||eu-mobile.events.data.microsoft.com^$dnsrewrite=NXDOMAIN"
      ];

      tls = {
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
        file = "syslog";
      };

      querylog = {
        enabled = true;
        file_enabled = true;
        interval = "2160h";
        size_memory = 10485760; # 10MiB
      };

      statistics = {
        enabled = true;
        interval = "744h";
      };
    };
  };

  systemd.services.adguardhome = {
    wants = [
      "network-online.target"
    ];
    after = [
      "network-online.target"
    ]
    ++ (lib.optional config.services.tailscale.enable "tailscaled.service");
    #++ (lib.optional config.services.zerotierone.enable "zerotierone.service");
  };
}
