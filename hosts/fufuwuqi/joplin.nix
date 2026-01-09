{ config, ... }:

{
  users.groups.joplin = { };
  users.users.joplin = {
    isSystemUser = true;
    group = "joplin";
  };

  virtualisation.oci-containers.containers.joplin-server = {
    image = "joplin/server:latest";
    user = "${toString config.users.users.joplin.uid}:${toString config.users.groups.joplin.gid}";
    ports = [ "22300:22300" ];
    environmentFiles = [ config.sops.secrets."joplin-env".path ];
  };

  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 22300 ];

  # Ensure the container can reach the host's MariaDB on the VPN IP
  # if using the default bridge network.

  sops.secrets."joplin-env" = {
    mode = "0600";
    owner = "joplin";
    group = "joplin";
  };
}
