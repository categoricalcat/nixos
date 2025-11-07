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
          addresses.dns.quad9
          ++ addresses.dns.adguard
          ++ addresses.dns.google
          ++ addresses.dns.cloudflare
          ++ addresses.dns.opendns
          ++ addresses.dns.nextdns
          ++ addresses.dns.freedns;

        # opts: load_balance, parallel, fastest_addr
        # load_balance: weighted random algorithm to select the best upstream server.
        # parallel: Parallel queries to all configured upstream servers to speed up resolving.
        # fastest_addr: It finds an IP address with the lowest latency and returns this IP address in DNS response.
        upstream_mode = "fastest_addr";

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
        server_name = "${addresses.hostName}.${addresses.dns.domain}";
        port_https = 443;
        port_dns_over_tls = 853;
        port_dns_over_quic = 853;

        # Self-signed certificate configuration
        # AdGuard will auto-generate these if they don't exist
        certificate_path = "/var/lib/private/adguardhome/certs/cert.pem";
        private_key_path = "/var/lib/private/adguardhome/certs/key.pem";

        # Enable all secure DNS protocols
        serve_plain_dns = true;
        allow_unencrypted_doh = false;
        strict_sni_check = false;
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
