{
  addresses,
  allAddresses,
  config,
  ...
}:

let
  yifuwuqiLan = allAddresses.hosts.yifuwuqi.network.lan.ipv4.host;
  acmeResolvers = map (resolver: "--dns.resolvers=${resolver}") (
    addresses.dns.fallbackServers or [ "9.9.9.9:53" ]
  );
in
{
  imports = [ ./shared-auth.nix ];

  sops.secrets = {
    cloudflare_api_token = { };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@fufu.land";

    certs."fufu.land" = {
      domain = "*.fufu.land";
      extraDomainNames = [ "fufu.land" ];
      dnsProvider = "cloudflare";
      credentialsFile = config.sops.secrets.cloudflare_api_token.path;
      extraLegoFlags = acmeResolvers;
      group = "nginx";
    };
  };

  users.users.adguardhome.extraGroups = [ "nginx" ];
  users.users.adguardhome.isSystemUser = true;
  users.users.adguardhome.group = "nginx";

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    serverTokens = false;

    virtualHosts = {
      # Local test vhost
      "yirukou.local" = {
        serverName = "yirukou.local";
        forceSSL = false;
        locations."/" = {
          extraConfig = ''
            add_header Content-Type text/plain;
            return 200 "yirukou.local ok";
          '';
        };
      };

      "${addresses.network.tailscale.ipv4.host}" = {
        serverName = "${addresses.network.tailscale.ipv4.host}";
        forceSSL = false;
        locations."/" = {
          extraConfig = ''
            add_header Content-Type text/plain;
            return 200 "${addresses.network.tailscale.ipv4.host} ok";
          '';
        };
      };

      "fufu.land" = {
        forceSSL = false;
        extraConfig = ''
          add_header Content-Type text/markdown;
          return 200 "fufu.land is ok";
        '';
      };

      # Secure AdGuard Web UI
      "adguard.fufu.land" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:3333";
        };
      };

      # DNS-over-HTTPS Endpoint
      "dns.fufu.land" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/dns-query" = {
          proxyPass = "http://127.0.0.1:3333/dns-query";
        };
      };

      # Netdata web UI — local parent (shows both hosts via streaming)
      "netdata.fufu.land" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        basicAuthFile = config.sops.secrets."services/htpasswd".path;
        locations."/" = {
          proxyPass = "http://127.0.0.1:19999";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };

      # SearXNG private metasearch — proxied to yifuwuqi
      "search.fufu.land" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        basicAuthFile = config.sops.secrets."services/htpasswd".path;
        locations."/" = {
          proxyPass = "http://${yifuwuqiLan}:8888";
          extraConfig = ''
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };

      # Portainer container management UI — proxied to yifuwuqi
      "prtnr.fufu.land" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/" = {
          proxyPass = "https://${yifuwuqiLan}:9443";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_ssl_verify off;
            proxy_ssl_server_name on;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 1d;
            proxy_send_timeout 1d;
            client_max_body_size 1G;
          '';
        };
      };

      # Opencode System Server — proxied to yifuwuqi
      "agent.fufu.land" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${yifuwuqiLan}:3010";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 1d;
            proxy_send_timeout 1d;
            client_max_body_size 1G;
          '';
        };
      };

      # GoAccess real-time web log analyzer — local on yirukou
      "goaccess.fufu.land" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        basicAuthFile = config.sops.secrets."services/htpasswd".path;
        locations."/" = {
          proxyPass = "http://127.0.0.1:7890";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };

    };
  };
}
