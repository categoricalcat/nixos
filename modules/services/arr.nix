{
  config,
  lib,
  allAddresses,
  ...
}:

let
  inherit (config.networking) hostName;
  addrs = allAddresses.hosts.${hostName};
in
{
  sops.secrets = {
    "arr/radarr_api_key" = { };
    "arr/sonarr_api_key" = { };
    "arr/lidarr_api_key" = { };
    "arr/readarr_api_key" = { };
    "arr/prowlarr_api_key" = { };
  };

  sops.templates."arr-secrets.env".content = ''
    RADARR__AUTH__APIKEY=${config.sops.placeholder."arr/radarr_api_key"}
    SONARR__AUTH__APIKEY=${config.sops.placeholder."arr/sonarr_api_key"}
    LIDARR__AUTH__APIKEY=${config.sops.placeholder."arr/lidarr_api_key"}
    READARR__AUTH__APIKEY=${config.sops.placeholder."arr/readarr_api_key"}
    PROWLARR__AUTH__APIKEY=${config.sops.placeholder."arr/prowlarr_api_key"}
  '';

  users.groups.media = { };

  systemd.tmpfiles.rules = [
    "d /persist/media 2775 root media - -"
    "d /persist/media/downloads 2775 root media - -"
    "d /persist/media/downloads/incomplete 2775 root media - -"
    "d /persist/media/downloads/complete 2775 root media - -"
    "d /persist/media/movies 2775 root media - -"
    "d /persist/media/tv 2775 root media - -"
    "d /persist/media/music 2775 root media - -"
    "d /persist/media/books 2775 root media - -"
  ];

  services = {
    radarr = {
      enable = true;
      group = "media";
    };
    sonarr = {
      enable = true;
      group = "media";
    };
    lidarr = {
      enable = true;
      group = "media";
    };
    readarr = {
      enable = true;
      group = "media";
    };
    bazarr = {
      enable = true;
      group = "media";
      listenPort = addrs.services.bazarr.port;
    };
    jellyfin = {
      enable = true;
      group = "media";
    };
    prowlarr = {
      enable = true;
    };
    flaresolverr = {
      enable = true;
      port = addrs.services.flaresolverr.port;
    };
    recyclarr = {
      enable = true;
      configuration = {
        radarr = {
          radarr-main = {
            base_url = "http://127.0.0.1:${toString addrs.services.radarr.port}";
            api_key = "!env_var RADARR__AUTH__APIKEY";
            quality_definition = {
              type = "movie";
            };
            quality_profiles = [ { name = "HD Bluray + WEB"; } ];
          };
        };
        sonarr = {
          sonarr-main = {
            base_url = "http://127.0.0.1:${toString addrs.services.sonarr.port}";
            api_key = "!env_var SONARR__AUTH__APIKEY";
            quality_definition = {
              type = "series";
            };
            quality_profiles = [ { name = "WEB-1080p"; } ];
          };
        };
      };
    };
  };

  systemd.services = {
    radarr = {
      environment.RADARR__SERVER__PORT = toString addrs.services.radarr.port;
      serviceConfig = {
        EnvironmentFile = config.sops.templates."arr-secrets.env".path;
        UMask = lib.mkForce "0002";
        PrivateUsers = lib.mkForce "identity";
        ReadWritePaths = [ "/persist/media" ];
        IPAddressDeny = lib.mkForce [ ];
        IPAddressAllow = lib.mkForce [ ];
      };
    };
    sonarr = {
      environment.SONARR__SERVER__PORT = toString addrs.services.sonarr.port;
      serviceConfig = {
        EnvironmentFile = config.sops.templates."arr-secrets.env".path;
        UMask = lib.mkForce "0002";
        PrivateUsers = lib.mkForce "identity";
        ReadWritePaths = [ "/persist/media" ];
        IPAddressDeny = lib.mkForce [ ];
        IPAddressAllow = lib.mkForce [ ];
      };
    };
    lidarr = {
      environment.LIDARR__SERVER__PORT = toString addrs.services.lidarr.port;
      serviceConfig = {
        EnvironmentFile = config.sops.templates."arr-secrets.env".path;
        UMask = lib.mkForce "0002";
        PrivateUsers = lib.mkForce "identity";
        ReadWritePaths = [ "/persist/media" ];
        IPAddressDeny = lib.mkForce [ ];
        IPAddressAllow = lib.mkForce [ ];
      };
    };
    readarr = {
      environment.READARR__SERVER__PORT = toString addrs.services.readarr.port;
      serviceConfig = {
        EnvironmentFile = config.sops.templates."arr-secrets.env".path;
        UMask = lib.mkForce "0002";
        PrivateUsers = lib.mkForce "identity";
        ReadWritePaths = [ "/persist/media" ];
        IPAddressDeny = lib.mkForce [ ];
        IPAddressAllow = lib.mkForce [ ];
      };
    };
    bazarr = {
      serviceConfig = {
        UMask = lib.mkForce "0002";
        PrivateUsers = lib.mkForce "identity";
        ReadWritePaths = [ "/persist/media" ];
        IPAddressDeny = lib.mkForce [ ];
        IPAddressAllow = lib.mkForce [ ];
      };
    };
    jellyfin = {
      serviceConfig = {
        UMask = lib.mkForce "0002";
        PrivateUsers = lib.mkForce "identity";
        ReadWritePaths = [ "/persist/media" ];
      };
    };
    prowlarr = {
      environment.PROWLARR__SERVER__PORT = toString addrs.services.prowlarr.port;
      serviceConfig = {
        EnvironmentFile = config.sops.templates."arr-secrets.env".path;
        IPAddressDeny = lib.mkForce [ ];
        IPAddressAllow = lib.mkForce [ ];
      };
    };
    recyclarr = {
      serviceConfig.EnvironmentFile = config.sops.templates."arr-secrets.env".path;
    };
  };
}
