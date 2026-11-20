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

  # Chromium aborts when fontconfig reports zero font families
  flaresolverrFonts = pkgs.makeFontsConf {
    fontDirectories = [ pkgs.dejavu_fonts ];
    includes = [ "${pkgs.fontconfig.out}/etc/fonts/conf.d" ];
  };

  flaresolverrImage = pkgs.dockerTools.streamLayeredImage {
    name = "localhost/flaresolverr-nix";
    contents = [
      pkgs.dockerTools.caCertificates
      pkgs.dockerTools.fakeNss
      pkgs.dockerTools.usrBinEnv
      pkgs.dockerTools.binSh
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.dumb-init
      pkgs.flaresolverr
    ];
    extraCommands = ''
      mkdir -p tmp var/tmp
      chmod 1777 tmp var/tmp
    '';
    config = {
      User = "65534:65534";
      Entrypoint = [
        "${pkgs.dumb-init}/bin/dumb-init"
        "--"
      ];
      Cmd = [ "${pkgs.flaresolverr}/bin/flaresolverr" ];
      Env = [
        "HOME=/tmp"
        "LANG=C.UTF-8"
        "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
        "FONTCONFIG_FILE=${flaresolverrFonts}"
      ];
      WorkingDir = "/tmp";
    };
  };
  flaresolverrRef = "${flaresolverrImage.imageName}:${flaresolverrImage.imageTag}";
  gluetunUnit = "podman-gluetun.service";
  # Podman cannot replace Gluetun while a shared-network-namespace container remains.
  gluetunConsumers = [
    "soularr"
    "slskd"
    "torrent-indexer"
    "flaresolverr"
    "qbittorrent"
  ];
  gluetunConsumerUnits = map (name: "podman-${name}.service") gluetunConsumers;
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
      WebUI\AuthSubnetWhitelist=127.0.0.1
    '';
  };

  users = {
    # Rootful podman maps PUID straight to a host UID (owner of /config and
    # downloads); the pinned number renders into the unit at evaluation time.
    users.qbittorrent = {
      isSystemUser = true;
      uid = 331;
      group = "media";
    };
    groups.flaresolverr.gid = 333;
    users.flaresolverr = {
      isSystemUser = true;
      uid = 333;
      group = "flaresolverr";
    };
  };

  virtualisation.oci-containers.containers = {
    gluetun = {
      image = "docker.io/qmcgaw/gluetun:latest";
      # VPN namespace owner: NET_ADMIN and /dev/net/tun require root
      # (the container-identity contract in nix/checks.nix accepts a recorded
      # reason as compliance).
      rootReason = "needs NET_ADMIN and /dev/net/tun to create and manage the VPN namespace";
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
        "127.0.0.1:8889:8888"
        "127.0.0.1:${toString addrs.services.flaresolverr.port}:${toString addrs.services.flaresolverr.internalPort}"
        # Containers sharing gluetun's namespace publish through it
        "127.0.0.1:${toString addrs.services.torrent-indexer.port}:${toString addrs.services.torrent-indexer.port}"
        "127.0.0.1:${toString addrs.services.slskd.port}:${toString addrs.services.slskd.port}"
      ];
    };

    qbittorrent = {
      image = "lscr.io/linuxserver/qbittorrent:latest";
      dependsOn = [ "gluetun" ];
      # The s6 init must run as root to drop to PUID/PGID; the app itself
      # runs as the pinned account below.
      rootReason = "linuxserver s6-overlay init runs as root and drops to PUID/PGID";
      extraOptions = [
        "--network=container:gluetun"
        # SIGTERM saves resume data, then waits up to Session\ShutdownTimeout
        # (preStart) for libtorrent teardown; podman's 10s default SIGKILLs it.
        "--stop-timeout=30"
      ];
      environment = {
        UMASK = "002";
        PUID = toString config.users.users.qbittorrent.uid;
        PGID = toString config.users.groups.media.gid;
      };
      volumes = [
        "/var/lib/container-volumes/qbittorrent:/config"
        "/persist/media:/persist/media"
      ];
    };

    flaresolverr = {
      image = flaresolverrRef;
      dependsOn = [ "gluetun" ];
      extraOptions = [
        "--network=container:gluetun"
      ];
      # Overrides the image-baked nobody:nogroup with the declared account
      user = "${toString config.users.users.flaresolverr.uid}:${toString config.users.groups.flaresolverr.gid}";
      environment = {
        PORT = toString addrs.services.flaresolverr.internalPort;
      };
    };
  };

  systemd = {
    # Make sure the container volumes root directory exists
    tmpfiles.rules = [
      "d /var/lib/container-volumes/qbittorrent 0755 qbittorrent media - -"
    ];

    services = {
      "podman-gluetun".serviceConfig = {
        ExecStartPre = lib.mkBefore [
          "${pkgs.systemd}/bin/systemctl stop ${lib.concatStringsSep " " gluetunConsumerUnits}"
          "${config.virtualisation.podman.package}/bin/podman rm -f --ignore ${lib.concatStringsSep " " gluetunConsumers}"
        ];
        # Queue after the namespace owner is ready; consumers order after it.
        ExecStartPost = [
          "${pkgs.systemd}/bin/systemctl start --no-block ${lib.concatStringsSep " " gluetunConsumerUnits}"
        ];
      };

      "podman-qbittorrent" = {
        after = [ gluetunUnit ];
        bindsTo = [ gluetunUnit ];
        partOf = [ gluetunUnit ];
        preStart =
          let
            conf = "/var/lib/container-volumes/qbittorrent/qBittorrent/qBittorrent.conf";
            gid = "media";
          in
          ''
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
            ${pkgs.crudini}/bin/crudini --set ${conf} Preferences 'WebUI\AuthSubnetWhitelist'         "127.0.0.1"

            # Bound libtorrent teardown (default -1: unlimited). Its `stopped`
            # announces to every tracker below otherwise outlast --stop-timeout.
            ${pkgs.crudini}/bin/crudini --set ${conf} BitTorrent 'Session\ShutdownTimeout' 5

            # Fetch and inject ngosang's trackerslist (bounded so transient GitHub failures never stall boot)
            trackers=$(${lib.getExe pkgs.curl} -fsS --connect-timeout 5 --max-time 10 https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt | ${pkgs.gawk}/bin/awk NF | ${pkgs.gawk}/bin/awk 'NR>1 {printf "\\n"} {printf "%s", $0}' || true)
            if [ -n "$trackers" ]; then
              ${pkgs.crudini}/bin/crudini --set ${conf} BitTorrent 'Session\AdditionalTrackersEnabled' true
              ${pkgs.crudini}/bin/crudini --set ${conf} BitTorrent 'Session\AdditionalTrackers' "$trackers"
            fi

            chown -R qbittorrent:${gid} /var/lib/container-volumes/qbittorrent
          '';
      };

      "podman-flaresolverr" = {
        after = [ gluetunUnit ];
        bindsTo = [ gluetunUnit ];
        partOf = [ gluetunUnit ];
        # imageStream would re-stream the whole image on every (re)start
        preStart = "podman image exists ${flaresolverrRef} || ${flaresolverrImage} | podman load";
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
      timerConfig = config.yi.maintenance.slots.gluetunRotate.timerConfig // {
        OnCalendar = config.yi.maintenance.slots.gluetunRotate.calendar;
      };
    };
  };
}
