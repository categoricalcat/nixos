{ config, allAddresses, ... }:

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
      WebUI\AuthSubnetWhitelist=10.42.0.0/24, 100.42.0.0/16
    '';
  };

  # Make sure the container volumes root directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/container-volumes/qbittorrent 0755 999 media - -"
  ];

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
      };
      environmentFiles = [
        config.sops.templates."gluetun.env".path
      ];
      ports = [
        "127.0.0.1:${toString addrs.services.qbittorrent.port}:8080"
        "10.42.0.2:${toString addrs.services.qbittorrent.port}:8080"
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
        PGID = toString config.users.groups.media.gid;
        UMASK = "002";
      };
      volumes = [
        "/var/lib/container-volumes/qbittorrent:/config"
        "/persist/media:/persist/media"
      ];
    };
  };

  systemd.services."podman-qbittorrent" = {
    after = [ "podman-gluetun.service" ];
    bindsTo = [ "podman-gluetun.service" ];
    preStart = ''
      mkdir -p /var/lib/container-volumes/qbittorrent/qBittorrent
      if [ ! -f /var/lib/container-volumes/qbittorrent/qBittorrent/qBittorrent.conf ]; then
        cp ${
          config.sops.templates."qbittorrent.conf".path
        } /var/lib/container-volumes/qbittorrent/qBittorrent/qBittorrent.conf
        chown -R 999:${toString config.users.groups.media.gid} /var/lib/container-volumes/qbittorrent
      fi
    '';
  };
}
