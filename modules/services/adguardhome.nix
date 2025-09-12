{ addresses, ... }:
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
          "0.0.0.0"
          "::"
        ];

        upstream_dns =
          addresses.dns.quad9 ++ addresses.dns.adguard ++ addresses.dns.google ++ addresses.dns.cloudflare;

        upstream_mode = "load_balance";

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
        cache_size = 200000; # entries
        max_goroutines = 300;
        upstream_timeout = "4s";
        serve_http3 = true;
      };

      filtering = {
        rewrites = [
          {
            domain = "${addresses.hostName}.${addresses.dns.domain}";
            answer = addresses.network.vpn.ipv4.host;
          }
          {
            domain = "${addresses.hostName}.lan";
            answer = addresses.network.lan.ipv4.host;
          }
          {
            domain = "${addresses.hostName}";
            answer = addresses.network.lan.ipv4.host;
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
          url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt";
          name = "Hagezi Multi PRO Adblock List";
          enabled = true;
        }
      ];

      tls = {
        enabled = false;
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
    ];
  };
}
