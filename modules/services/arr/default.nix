{
  config,
  lib,
  pkgs,
  allAddresses,
  systemdHardening,
  ...
}:

let
  inherit (config.networking) hostName;
  addrs = allAddresses.hosts.${hostName};
  envFile = config.sops.templates."arr-secrets.env".path;

  # Recyclarr's `custom_formats` accepts only TRaSH guide trash_ids, so a local
  # release-title regex ships as a `custom-formats` resource provider. ptBrId is
  # the contract between that JSON and the instance config; the score lives once
  # as `trash_scores.default`, which recyclarr reads as DefaultScore.
  ptBrId = "ptbr-dubbed-dual-audio";
  # Paths here are relative to RECYCLARR_CONFIG_DIR (/var/lib/recyclarr).
  ptBrDir = "custom-formats";

  ptBrFormat = (pkgs.formats.json { }).generate "${ptBrId}.json" {
    trash_id = ptBrId;
    trash_scores.default = 50;
    name = "pt-BR Dubbed / Dual Audio";
    specifications = [
      {
        name = "pt-BR";
        implementation = "ReleaseTitleSpecification";
        negate = false;
        required = false;
        # Not arr-stack.md's old pattern: that one misses "Dual-Áudio",
        # "DUALÁUDIO" and "_DUBLADO_" (accented Áudio; `_` is a word char, so
        # \b never fires). This one matches all 9 corpus positives and rejects
        # all 9 negatives, including "dualpixel".
        fields.value = "(?i)(?:^|[^a-z0-9])(dublado|dual[\\W_]?(?:[aá]udio)|pt[\\W_]?br)(?:$|[^a-z0-9])";
      }
    ];
  };

  recyclarrSettings = (pkgs.formats.yaml { }).generate "recyclarr-settings.yml" {
    resource_providers =
      map
        (service: {
          name = "ptbr-${service}";
          type = "custom-formats";
          inherit service;
          path = ptBrDir;
        })
        [
          "radarr"
          "sonarr"
        ];
  };

  ptBrCustomFormats = [
    {
      trash_ids = [ ptBrId ];
      assign_scores_to = [ { name = "All-in-One"; } ];
    }
  ];

  # radarr and sonarr get this set from nixpkgs; its lidarr, readarr and prowlarr modules set none of it
  servarrHardening =
    removeAttrs systemdHardening [
      "ProtectSystem"
      "MemoryDenyWriteExecute"
    ]
    // {
      RemoveIPC = true;
      SystemCallFilter = lib.splitString " " "@system-service ~@privileged ~@debug ~@mount @chown";
    };

  mediaService = {
    UMask = lib.mkForce "0002";
    PrivateUsers = lib.mkForce "identity";
    ReadWritePaths = [ "/persist/media" ];
  };

  # The Authelia gate on yirukou is the only login in front of the UIs; API
  # clients keep using the arr/*_api_key secrets.
  externalAuth.method = "External";
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

  users = {
    groups = {
      media.gid = 330;
      torrent-indexer.gid = 342;
    };
    users.torrent-indexer = {
      isSystemUser = true;
      uid = 342;
      group = "torrent-indexer";
    };
  };

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
      settings.server = {
        port = addrs.services.radarr.port;
        bindaddress = "127.0.0.1";
      };
      settings.auth = externalAuth;
    };
    sonarr = {
      enable = true;
      group = "media";
      settings.server = {
        port = addrs.services.sonarr.port;
        bindaddress = "127.0.0.1";
      };
      settings.auth = externalAuth;
    };
    # soularr reaches Lidarr over the LAN address, so it keeps a non-loopback
    # bind; the local ingress fronts it there too (upstreamLan).
    lidarr = {
      enable = true;
      group = "media";
      settings.server = {
        port = addrs.services.lidarr.port;
        bindaddress = addrs.network.lan.ipv4.host;
      };
      settings.auth = externalAuth;
    };
    readarr = {
      enable = true;
      group = "media";
      settings.server = {
        port = addrs.services.readarr.port;
        bindaddress = "127.0.0.1";
      };
      settings.auth = externalAuth;
    };
    bazarr = {
      enable = true;
      group = "media";
      settings.general = {
        port = addrs.services.bazarr.port;
        ip = "127.0.0.1";
      };
      # No login of its own; the Authelia gate on yirukou fronts the UI.
      settings.auth.type = null;
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
      settings.server = {
        port = addrs.services.prowlarr.port;
        bindaddress = "127.0.0.1";
      };
      settings.auth = externalAuth;
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
            custom_formats = ptBrCustomFormats;
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
            custom_formats = ptBrCustomFormats;
          };
        };
      };
    };
  };

  virtualisation.oci-containers.containers.torrent-indexer = {
    # Trivy 2026-11: 39 C+H (all fixable); :latest == newest release 0.15.3 —
    # the upstream image pre-dates the fixes. Accepted; auto-update tracks fixes.
    image = "docker.io/felipemarinho97/torrent-indexer:latest";
    # Share gluetun's network namespace (like FlareSolverr): outbound traffic
    # goes through the VPN and FlareSolverr is reachable on 127.0.0.1.
    dependsOn = [ "gluetun" ];
    extraOptions = [ "--network=container:gluetun" ];
    user = "${toString config.users.users.torrent-indexer.uid}:${toString config.users.groups.torrent-indexer.gid}";
    environment = {
      # 8080 is taken by qBittorrent inside the shared namespace; the host
      # publishes this port through gluetun.
      PORT = toString addrs.services.torrent-indexer.port;
      # Same netns as FlareSolverr: use the in-container listen port, not the host publish.
      FLARESOLVERR_URL = "http://127.0.0.1:${toString addrs.services.flaresolverr.internalPort}";
    };
  };

  systemd.services = {
    radarr.serviceConfig = mediaService // {
      EnvironmentFile = envFile;
    };
    sonarr.serviceConfig = mediaService // {
      EnvironmentFile = envFile;
    };
    lidarr.serviceConfig =
      servarrHardening
      // mediaService
      // {
        EnvironmentFile = envFile;
      };
    readarr.serviceConfig =
      servarrHardening
      // mediaService
      // {
        EnvironmentFile = envFile;
      };
    bazarr.serviceConfig = mediaService;
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
    # Node.js JIT needs writable executable mappings, and its fs layer chowns
    # (@chown sits outside @system-service; same exception as servarrHardening).
    seerr.serviceConfig = removeAttrs systemdHardening [ "MemoryDenyWriteExecute" ] // {
      SystemCallFilter = lib.splitString " " "@system-service ~@privileged @chown";
      UMask = lib.mkForce "0002";
    };
    prowlarr.serviceConfig = servarrHardening // {
      PrivateUsers = true;
      EnvironmentFile = envFile;
    };
    recyclarr = {
      # The module generates only config.yml; the pt-BR custom format needs a
      # settings.yml and its JSON alongside it. Recyclarr's keys arrive via
      # LoadCredential, so this unit gets no EnvironmentFile.
      preStart = lib.mkAfter ''
        install -Dm644 ${recyclarrSettings} /var/lib/recyclarr/settings.yml
        install -Dm644 ${ptBrFormat} /var/lib/recyclarr/${ptBrDir}/${ptBrId}.json
      '';
    };
    "podman-torrent-indexer" = {
      after = [ "podman-gluetun.service" ];
      bindsTo = [ "podman-gluetun.service" ];
      partOf = [ "podman-gluetun.service" ];
    };
  };
}
