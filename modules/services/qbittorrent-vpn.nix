{
  config,
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
    "services/proton/wireguard_private_key" = { };
  };

  sops.templates = {
    "gluetun.env".content = ''
      WIREGUARD_PRIVATE_KEY=${config.sops.placeholder."services/proton/wireguard_private_key"}
    '';
    "qbittorrent.conf".content = ''
      [Preferences]
      Connection\Interface=tun0
      Connection\InterfaceName=tun0
      WebUI\LocalHostAuth=false
      WebUI\AuthSubnetWhitelistEnabled=true
      WebUI\AuthSubnetWhitelist=127.0.0.1, 10.42.0.0/24, 100.42.0.0/16, 10.88.0.0/16, 172.16.0.0/12
    '';
  };

  virtualisation.oci-containers.containers = {
    gluetun = {
      image = "docker.io/qmcgaw/gluetun:latest";
      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--device=/dev/net/tun:/dev/net/tun"
        "--sysctl=net.ipv6.conf.all.disable_ipv6=1"
        "--sysctl=net.ipv4.conf.all.src_valid_mark=1"
      ];
      environment = {
        VPN_SERVICE_PROVIDER = "protonvpn";
        VPN_TYPE = "wireguard";
        PORT_FORWARD_ONLY = "on";
        VPN_PORT_FORWARDING = "on";
        VPN_PORT_FORWARDING_PROVIDER = "protonvpn";
        VPN_PORT_FORWARDING_UP_COMMAND = "wget -O- --retry-connrefused --post-data 'json={\"listen_port\":'$1',\"upnp\":false,\"random_port\":false}' http://127.0.0.1:8080/api/v2/app/setPreferences";
        HTTPPROXY = "on";
      };
      environmentFiles = [
        config.sops.templates."gluetun.env".path
      ];
      ports = [
        "127.0.0.1:${toString addrs.services.qbittorrent.port}:8080"
        "${addrs.network.lan.ipv4.host}:${toString addrs.services.qbittorrent.port}:8080"
        "127.0.0.1:8889:8888"
        "${toString addrs.services.flaresolverr.port}:${toString addrs.services.flaresolverr.internalPort}"
        # Containers sharing gluetun's namespace publish through it
        "127.0.0.1:${toString addrs.services.torrent-indexer.port}:${toString addrs.services.torrent-indexer.port}"
        "${addrs.network.lan.ipv4.host}:${toString addrs.services.torrent-indexer.port}:${toString addrs.services.torrent-indexer.port}"
        "127.0.0.1:${toString addrs.services.slskd.port}:${toString addrs.services.slskd.port}"
        "${addrs.network.lan.ipv4.host}:${toString addrs.services.slskd.port}:${toString addrs.services.slskd.port}"
      ];
    };

    qbittorrent = {
      image = "lscr.io/linuxserver/qbittorrent:latest";
      dependsOn = [ "gluetun" ];
      extraOptions = [
        "--network=container:gluetun"
      ];
      environment = {
        PUID = "999";
        UMASK = "002";
      };
      environmentFiles = [
        "/run/qbittorrent-pgid.env"
      ];
      volumes = [
        "/var/lib/container-volumes/qbittorrent:/config"
        "/persist/media:/persist/media"
      ];
    };

    flaresolverr = {
      image = "ghcr.io/flaresolverr/flaresolverr:latest";
      dependsOn = [ "gluetun" ];
      extraOptions = [
        "--network=container:gluetun"
      ];
      environment = {
        PORT = toString addrs.services.flaresolverr.internalPort;
      };
    };
  };

  systemd = {
    # Make sure the container volumes root directory exists
    tmpfiles.rules = [
      "d /var/lib/container-volumes/qbittorrent 0755 999 media - -"
    ];

    services = {
      "podman-qbittorrent" = {
        after = [ "podman-gluetun.service" ];
        bindsTo = [ "podman-gluetun.service" ];
        preStart =
          let
            conf = "/var/lib/container-volumes/qbittorrent/qBittorrent/qBittorrent.conf";
            gid = "media";
          in
          ''
            # Resolve media group GID at runtime for the container
            echo "PGID=$(${pkgs.coreutils}/bin/stat -c %g /persist/media)" > /run/qbittorrent-pgid.env

            mkdir -p /var/lib/container-volumes/qbittorrent/qBittorrent

            # Seed template on first run
            if [ ! -f ${conf} ]; then
              cp ${config.sops.templates."qbittorrent.conf".path} ${conf}
            fi

            # Always enforce auth / interface settings
            ${pkgs.crudini}/bin/crudini --set ${conf} Preferences 'Connection\Interface'              tun0
            ${pkgs.crudini}/bin/crudini --set ${conf} Preferences 'Connection\InterfaceName'          tun0
            ${pkgs.crudini}/bin/crudini --set ${conf} Preferences 'WebUI\LocalHostAuth'               false
            ${pkgs.crudini}/bin/crudini --set ${conf} Preferences 'WebUI\AuthSubnetWhitelistEnabled'  true
            ${pkgs.crudini}/bin/crudini --set ${conf} Preferences 'WebUI\AuthSubnetWhitelist'         "127.0.0.1, 10.42.0.0/24, 100.42.0.0/16, 10.88.0.0/16, 172.16.0.0/12"

            # Fetch and inject ngosang's trackerslist
            trackers=$(${pkgs.curl}/bin/curl -s https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt | ${pkgs.gawk}/bin/awk NF | ${pkgs.gawk}/bin/awk 'NR>1 {printf "\\n"} {printf "%s", $0}')
            if [ -n "$trackers" ]; then
              ${pkgs.crudini}/bin/crudini --set ${conf} BitTorrent 'Session\AdditionalTrackersEnabled' true
              ${pkgs.crudini}/bin/crudini --set ${conf} BitTorrent 'Session\AdditionalTrackers' "$trackers"
            fi

            chown -R 999:${gid} /var/lib/container-volumes/qbittorrent
          '';
      };

      "podman-flaresolverr" = {
        after = [ "podman-gluetun.service" ];
        bindsTo = [ "podman-gluetun.service" ];
      };

      "restart-gluetun" = {
        description = "Restart Gluetun VPN to rotate IP";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.systemd}/bin/systemctl restart podman-gluetun.service";
        };
      };
    };

    timers."restart-gluetun" = {
      description = "Timer to restart Gluetun VPN every 6 hours";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "6h";
        OnUnitActiveSec = "6h";
        RandomizedDelaySec = "5m";
      };
    };
  };
}
