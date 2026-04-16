{
  config,
  lib,
  pkgs,
  inputs,
  allAddresses,
  ...
}:

let
  unstable = import ../nixpkgs-unstable.nix { inherit inputs pkgs; };
  cfg = config.services.tailscale;
  isServer = cfg.useRoutingFeatures == "server" || cfg.useRoutingFeatures == "both";
in
{
  services.tailscale = {
    enable = lib.mkDefault true;
    package = unstable.tailscale;
    useRoutingFeatures = lib.mkDefault "client";
    extraUpFlags =
      if isServer then
        [
          "--advertise-exit-node"
          "--advertise-routes=192.168.0.0/24,2001:db8::1/128"
          "--accept-dns=true"
        ]
      else
        [
          "--accept-dns=true"
          "--accept-routes"
          "--exit-node=${allAddresses.hosts.yifuwuqi.network.tailscale.ipv4.host}"
        ];
  };

  networking.firewall = {
    trustedInterfaces = [ config.services.tailscale.interfaceName ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };
}
