{
  addresses,
  config,
  ...
}:

{
  sops.secrets.cloudflare_api_token = { };

  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@fufu.land";

    certs."fufu.land" = {
      domain = "*.fufu.land";
      extraDomainNames = [ "fufu.land" ];
      dnsProvider = "cloudflare";
      # The credentialsFile must point to the decrypted SOPS secret:
      credentialsFile = config.sops.secrets.cloudflare_api_token.path;
      group = "nginx";
    };
  };

  # Add adguardhome to the nginx group to read the TLS certs natively
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
      "yifuwuqi.local" = {
        serverName = "yifuwuqi.local";
        forceSSL = false;
        locations."/" = {
          extraConfig = ''
            add_header Content-Type text/plain;
            return 200 "yifuwuqi.local ok";
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
    };
  };
}
