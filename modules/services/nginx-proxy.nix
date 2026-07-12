{
  addresses,
  allAddresses,
  config,
  ...
}:

let
  yifuwuqiLan = allAddresses.hosts.yifuwuqi.network.lan.ipv4.host;
  yifuwuqiServices = allAddresses.hosts.yifuwuqi.services;
  trustedProxyCidrs = [
    allAddresses.hosts.yirukou.network.lan.ipv4.cidr
    # allAddresses.hosts.yifuwuqi.network.tailscale.ipv4.cidr
    allAddresses.hosts.yifuwuqi.network.vpn.ipv4.cidr
  ];
  restrictedProxyConfig = ''
    ${builtins.concatStringsSep "\n" (map (cidr: "allow ${cidr};") trustedProxyCidrs)}
    deny all;
  '';
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
      environmentFile = config.sops.secrets.cloudflare_api_token.path;
      extraLegoFlags = acmeResolvers;
      group = "nginx";
    };
  };

  users.users.adguardhome = {
    extraGroups = [ "nginx" ];
    isSystemUser = true;
    group = "nginx";
  };

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

      "${addresses.network.vpn.ipv4.host}" = {
        serverName = "${addresses.network.vpn.ipv4.host}";
        forceSSL = false;
        locations."/" = {
          extraConfig = ''
            add_header Content-Type text/plain;
            return 200 "${addresses.network.vpn.ipv4.host} ok";
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

      # Netdata web UI — yifuwuqi parent (shows both hosts via streaming)
      "netdata.fufu.land" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        basicAuthFile = config.sops.secrets."services/htpasswd".path;
        locations."/" = {
          proxyPass = "http://${yifuwuqiLan}:19999";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };

      # Grafana dashboards — yifuwuqi observability stack
      "${yifuwuqiServices.grafana.domain}" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.grafana.port}";
          proxyWebsockets = true;
        };
      };

      # Cockpit host management — proxied to yifuwuqi
      "${yifuwuqiServices.cockpit.domain}" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.cockpit.port}";
          proxyWebsockets = true;
          extraConfig = restrictedProxyConfig;
        };
      };

      # SearXNG private metasearch — proxied to yifuwuqi
      "search.fufu.land" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${yifuwuqiLan}:8888";
          extraConfig = ''
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };

      # Attic Binary Cache — proxied to yifuwuqi
      "${yifuwuqiServices.attic.domain}" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.attic.port}";
          extraConfig = restrictedProxyConfig;
        };
      };

      # Forgejo git forge — proxied to yifuwuqi
      "${yifuwuqiServices.forgejo.domain}" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.forgejo.httpPort}";
          extraConfig = ''
            client_max_body_size 512M;
            ${restrictedProxyConfig}
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

      # Arr stack and qBittorrent — proxied to yifuwuqi
      "${yifuwuqiServices.radarr.domain}" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.radarr.port}";
          proxyWebsockets = true;
          extraConfig = restrictedProxyConfig;
        };
      };
      "${yifuwuqiServices.sonarr.domain}" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.sonarr.port}";
          proxyWebsockets = true;
          extraConfig = restrictedProxyConfig;
        };
      };
      "${yifuwuqiServices.lidarr.domain}" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.lidarr.port}";
          proxyWebsockets = true;
          extraConfig = restrictedProxyConfig;
        };
      };
      "${yifuwuqiServices.readarr.domain}" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.readarr.port}";
          proxyWebsockets = true;
          extraConfig = restrictedProxyConfig;
        };
      };
      "${yifuwuqiServices.prowlarr.domain}" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.prowlarr.port}";
          proxyWebsockets = true;
          extraConfig = restrictedProxyConfig;
        };
      };
      "${yifuwuqiServices.bazarr.domain}" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.bazarr.port}";
          proxyWebsockets = true;
          extraConfig = restrictedProxyConfig;
        };
      };
      "${yifuwuqiServices.jellyfin.domain}" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.jellyfin.port}";
          proxyWebsockets = true;
          extraConfig = restrictedProxyConfig;
        };
      };
      "${yifuwuqiServices.qbittorrent.domain}" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.qbittorrent.port}";
          proxyWebsockets = true;
          extraConfig = restrictedProxyConfig;
        };
      };
    };
  };
}
