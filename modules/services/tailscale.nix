{
  lib,
  pkgs,
  inputs,
  ...
}:

let
  unstable = import ../nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
  services.tailscale = {
    enable = lib.mkDefault true;
    package = unstable.tailscale;
    useRoutingFeatures = lib.mkDefault "client";
  };
}
