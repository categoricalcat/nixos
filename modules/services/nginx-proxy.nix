{
  addresses,
  allAddresses,
  config,
  lib,
  ...
}:

let
  trustedProxyCidrs = [
    allAddresses.hosts.yirukou.network.lan.ipv4.cidr
    allAddresses.hosts.yirukou.network.lan.ipv6.cidr
  ];
  restrictedProxyConfig = ''
    ${builtins.concatStringsSep "\n" (map (cidr: "allow ${cidr};") trustedProxyCidrs)}
    deny all;
  '';
  # Use Cloudflare's public DNS exclusively for ACME propagation since we use Cloudflare DNS-01
  cloudflareIpv4 = lib.filter (ns: !lib.hasInfix ":" ns) addresses.dns.cloudflare;
  acmeResolvers = map (ns: "--dns.resolvers=${ns}:53") cloudflareIpv4;
  proxyLib = import ./proxy-vhosts.nix { inherit lib; };
in
{

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

    certs."${allAddresses.baseDomain}" = {
      domain = "*.${allAddresses.baseDomain}";
      extraDomainNames = [ allAddresses.baseDomain ];
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
          proxyPass = "http://127.0.0.1:${toString addresses.services.adguardhome.port}";
          extraConfig = restrictedProxyConfig;
        };
      };

      # DNS-over-HTTPS Endpoint
      "dns.fufu.land" = {
        useACMEHost = "fufu.land";
        forceSSL = true;
        locations."/dns-query" = {
          proxyPass = "http://127.0.0.1:${toString addresses.services.adguardhome.port}/dns-query";
          extraConfig = restrictedProxyConfig;
        };
      };

      # # Netdata web UI — yifuwuqi parent (shows both hosts via streaming)
      # "netdata.fufu.land" = {
      #   useACMEHost = "fufu.land";
      #   forceSSL = true;
      #
      #   locations."/" = {
      #     proxyPass = "http://${allAddresses.hosts.yifuwuqi.network.lan.ipv4.host}:19999";
      #     proxyWebsockets = true;
      #     extraConfig = ''
      #       proxy_set_header X-Forwarded-Host $host;
      #       proxy_set_header X-Forwarded-Proto $scheme;
      #     '';
      #   };
      # };

      # GoAccess real-time web log analyzer — local on yirukou
      "goaccess.fufu.land" = {
        useACMEHost = "fufu.land";
        forceSSL = true;

        locations."/" = {
          root = "/var/lib/goaccess";
          index = "index.html";
          extraConfig = restrictedProxyConfig;
        };

        locations."/ws" = {
          proxyPass = "http://127.0.0.1:7890";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_read_timeout 3600;
            proxy_send_timeout 3600;
            ${restrictedProxyConfig}
          '';
        };
      };

    }
    // proxyLib.mkRemoteVhosts { inherit allAddresses restrictedProxyConfig; };
  };
}
