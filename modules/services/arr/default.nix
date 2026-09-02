{
  config,
  lib,
  pkgs,
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
      settings.server.port = addrs.services.radarr.port;
    };
    sonarr = {
      enable = true;
      group = "media";
      settings.server.port = addrs.services.sonarr.port;
    };
    lidarr = {
      enable = true;
      group = "media";
      settings.server.port = addrs.services.lidarr.port;
    };
    readarr = {
      enable = true;
      group = "media";
      settings.server.port = addrs.services.readarr.port;
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
    seerr = {
      enable = true;
      port = addrs.services.jellyseerr.port;
    };
    prowlarr = {
      enable = true;
      settings.server.port = addrs.services.prowlarr.port;
    };

    recyclarr = {
      enable = true;
      configuration = {
        radarr = {
          radarr-main = {
            base_url = "http://127.0.0.1:${toString addrs.services.radarr.port}";
            api_key = {
              _secret = config.sops.secrets."arr/radarr_api_key".path;
            };
            quality_definition = {
              type = "movie";
            };
            quality_profiles = [ { name = "All-in-One"; } ];
          };
        };
        sonarr = {
          sonarr-main = {
            base_url = "http://127.0.0.1:${toString addrs.services.sonarr.port}";
            api_key = {
              _secret = config.sops.secrets."arr/sonarr_api_key".path;
            };
            quality_definition = {
              type = "series";
            };
            quality_profiles = [ { name = "All-in-One"; } ];
          };
        };
      };
    };
  };

  virtualisation.oci-containers.containers.torrent-indexer = {
    image = "felipemarinho97/torrent-indexer:latest";
    # Share gluetun's network namespace (like FlareSolverr): outbound traffic
    # goes through the VPN and FlareSolverr is reachable on 127.0.0.1.
    dependsOn = [ "gluetun" ];
    extraOptions = [ "--network=container:gluetun" ];
    environment = {
      # 8080 is taken by qBittorrent inside the shared namespace; the host
      # publishes this port through gluetun.
      PORT = toString addrs.services.torrent-indexer.port;
      # Same netns as FlareSolverr: use the in-container listen port, not the host publish.
      FLARESOLVERR_URL = "http://127.0.0.1:${toString addrs.services.flaresolverr.internalPort}";
    };
  };

  systemd.services = {
    radarr = {
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
      # Jellyfin has no declarative port option: InternalHttpPort lives in
      # mutable network.xml. Only rewrite listen ports on an existing file;
      # PublicHttpPort is advertised/UPnP and stays untouched.
      preStart = lib.mkBefore ''
        networkXml=${lib.escapeShellArg "${config.services.jellyfin.configDir}/network.xml"}
        port=${toString addrs.services.jellyfin.port}
        if [ -e "$networkXml" ]; then
          ${pkgs.gnused}/bin/sed -i \
            -e "s|<InternalHttpPort>[0-9]*</InternalHttpPort>|<InternalHttpPort>$port</InternalHttpPort>|" \
            -e "s|<HttpServerPortNumber>[0-9]*</HttpServerPortNumber>|<HttpServerPortNumber>$port</HttpServerPortNumber>|" \
            "$networkXml"
        fi
      '';
      serviceConfig = {
        UMask = lib.mkForce "0002";
        PrivateUsers = lib.mkForce "identity";
        ReadWritePaths = [ "/persist/media" ];
        SupplementaryGroups = [
          "render"
          "video"
        ];
      };
    };
    seerr = {
      serviceConfig = {
        UMask = lib.mkForce "0002";
      };
    };
    prowlarr = {
      serviceConfig = {
        EnvironmentFile = config.sops.templates."arr-secrets.env".path;
        IPAddressDeny = lib.mkForce [ ];
        IPAddressAllow = lib.mkForce [ ];
      };
    };
    recyclarr = {
      serviceConfig.EnvironmentFile = config.sops.templates."arr-secrets.env".path;
    };
    # Restart with gluetun: the torrent-indexer shares its network namespace.
    "podman-torrent-indexer" = {
      after = [ "podman-gluetun.service" ];
      bindsTo = [ "podman-gluetun.service" ];
    };
  };
}
