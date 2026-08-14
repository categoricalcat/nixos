{
  config,
  allAddresses,
  ...
}:

let
  inherit (config.networking) hostName;
  addrs = allAddresses.hosts.${hostName};
  inherit (addrs) services;
  lanHost = addrs.network.lan.ipv4.host;
in
{
  sops.secrets = {
    "services/slskd/username" = { };
    "services/slskd/password" = { };
    "services/slskd/web_password" = { };
    "services/slskd/api_key" = { };
  };

  sops.templates = {
    "slskd.yml".content = ''
      soulseek:
        username: ${config.sops.placeholder."services/slskd/username"}
        password: ${config.sops.placeholder."services/slskd/password"}
        listen_ip_address: 0.0.0.0
        listen_port: ${toString services.slskd.listenPort}
      directories:
        downloads: /downloads
      web:
        port: ${toString services.slskd.port}
        ip_address: 0.0.0.0
        authentication:
          username: slskd
          password: ${config.sops.placeholder."services/slskd/web_password"}
          api_keys:
            soularr:
              key: ${config.sops.placeholder."services/slskd/api_key"}
              role: readwrite
    '';

    # download_dir is the path as seen by Lidarr on the host; the Slskd
    # download_dir below is the container path for the same directory.
    "soularr.ini".content = ''
      [Lidarr]
      api_key = ${config.sops.placeholder."arr/lidarr_api_key"}
      # Lidarr is a host service; the LAN IP is reachable from the gluetun
      # network namespace (allowed by backend-ui-guard for container subnets).
      host_url = http://${lanHost}:${toString services.lidarr.port}
      download_dir = /persist/media/downloads/soulseek
      disable_sync = False

      [Slskd]
      api_key = ${config.sops.placeholder."services/slskd/api_key"}
      host_url = http://127.0.0.1:${toString services.slskd.port}
      url_base = /
      download_dir = /downloads
      delete_searches = False
      stalled_timeout = 3600
      remote_queue_timeout = 300

      [Release Settings]
      use_selected_lidarr_release = False
      use_most_common_tracknum = True
      allow_multi_disc = True
      skip_region_check = True
      accepted_formats = CD,Digital Media,Vinyl

      [Search Settings]
      search_timeout = 5000
      maximum_peer_queue = 50
      minimum_peer_upload_speed = 0
      minimum_filename_match_ratio = 0.8
      minimum_search_interval = 5
      allowed_filetypes = flac 24/192,flac 16/44.1,flac,mp3 320,mp3
      album_prepend_artist = False
      search_type = incrementing_page
      number_of_albums_to_grab = 10
      search_source = missing
      failed_import_denylist = True

      [Download Settings]
      download_filtering = True
      use_extension_whitelist = False
      rename_download_folders = True

      [Logging]
      level = INFO
      log_to_file = True
      log_file = soularr.log
      max_bytes = 1048576
      backup_count = 3
    '';
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/container-volumes/slskd 0755 root root - -"
    "d /var/lib/container-volumes/soularr 0755 root root - -"
    "d /persist/media/downloads/soulseek 2775 root media - -"
    "Z /persist/media/downloads/soulseek 2775 root media - -"
  ];

  virtualisation.oci-containers.containers = {
    slskd = {
      image = "slskd/slskd:latest";
      # Share gluetun's network namespace: outbound Soulseek traffic goes
      # through the VPN. The Web UI port is published via gluetun.
      dependsOn = [ "gluetun" ];
      extraOptions = [
        "--network=container:gluetun"
        # Group-writable dirs/files so Lidarr can delete sources on import
        "--umask=0002"
      ];
      volumes = [
        "/var/lib/container-volumes/slskd:/app"
        "/persist/media/downloads/soulseek:/downloads"
        "${config.sops.templates."slskd.yml".path}:/app/slskd.yml:ro"
      ];
    };
    soularr = {
      image = "mrusse/soularr:latest";
      dependsOn = [ "slskd" ];
      extraOptions = [
        "--network=container:gluetun"
        # Keep downloads group-writable (files may be created during renames)
        "--umask=0002"
      ];
      environment = {
        SCRIPT_INTERVAL = "300";
        TZ = "America/Sao_Paulo";
        # Files land in /persist/media which is root:media (gid 952).
        PUID = "0";
        PGID = "952";
      };
      volumes = [
        "/var/lib/container-volumes/soularr:/data"
        "/persist/media/downloads/soulseek:/downloads"
        "${config.sops.templates."soularr.ini".path}:/data/config.ini:ro"
      ];
    };
  };

  systemd.services = {
    # Both containers share gluetun's namespace, so restart with it.
    "podman-slskd" = {
      after = [ "podman-gluetun.service" ];
      bindsTo = [ "podman-gluetun.service" ];
    };
    "podman-soularr" = {
      after = [ "podman-gluetun.service" ];
      bindsTo = [ "podman-gluetun.service" ];
    };
  };
}
