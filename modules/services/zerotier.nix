{ config, ... }:

{
  sops.secrets."zerotier/network_id" = { };

  services.zerotierone = {
    enable = true;
    joinNetworks = [ config.sops.placeholder."zerotier/network_id" ];
  };

  sops.templates."zerotier.env".content = config.sops.placeholder."zerotier/network_id";

  networking.firewall.trustedInterfaces = [ "zt+" ];
}
