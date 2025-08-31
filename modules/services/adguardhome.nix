{ addresses, ... }:
{
  services.adguardhome = {
    enable = true;
    host = "0.0.0.0";
    port = 3333;
    mutableSettings = false; # keep settings declarative
    settings = {
      # Web UI: bind away from default 3000
      http = {
        address = "0.0.0.0:3333";
        session_ttl = "12h";
      };

      # Listen on LAN and VPN addresses explicitly (IPv4/IPv6)
      dns = {
        bind_hosts = [
          "0.0.0.0"
          "::"
        ];
        # Upstreams: DoH/DoT; bootstrap for DoH resolution
        upstream_dns = addresses.dns.quad9 ++ addresses.dns.google ++ addresses.dns.cloudflare;
        bootstrap_dns = addresses.dns.quad9;
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
        upstream_timeout = "5s";
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

      tls = {
        enabled = false;
      };

      # Query log settings
      querylog_enabled = true;
      querylog_file_enabled = true;
      querylog_interval = "168h"; # one week
      querylog_size_memory = 10485760; # 10MiB
    };
  };
}
