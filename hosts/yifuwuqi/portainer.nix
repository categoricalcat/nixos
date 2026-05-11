{ addresses, ... }:
{
  systemd.tmpfiles.rules = [
    "d /var/lib/container-volumes/portainer 0750 root podman -"
  ];

  virtualisation.oci-containers.containers.portainer = {
    autoStart = true;
    image = "portainer/portainer-ce:lts";
    ports = [ "${addresses.network.lan.ipv4.host}:9443:9443" ];
    volumes = [
      "/var/lib/container-volumes/portainer:/data"
      "/run/podman/podman.sock:/var/run/docker.sock"
    ];
    extraOptions = [
      "--pull=newer"
      "--privileged"
    ];
  };

  systemd.services."podman-portainer" = {
    wants = [
      "network-online.target"
      "podman.socket"
    ];
    after = [
      "network-online.target"
      "podman.socket"
    ];
  };
}
