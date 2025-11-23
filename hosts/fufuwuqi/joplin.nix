{ config, ... }:

{
  virtualisation.oci-containers.containers.joplin-server = {
    image = "joplin/server:latest";
    ports = [ "22300:22300" ];
    environmentFiles = [ config.sops.secrets."joplin-env".path ];
  };

  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 22300 ];

  # Ensure the container can reach the host's MariaDB on the VPN IP
  # if using the default bridge network.
}
