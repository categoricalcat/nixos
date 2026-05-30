{
  config,
  lib,
  pkgs,
  inputs,
  allAddresses,
  ...
}:

let
  unstable = import ./nixpkgs-unstable.nix { inherit inputs pkgs; };
  yifuwuqiTs = allAddresses.hosts.yifuwuqi.network.tailscale.ipv4.host;
in
{
  nix = {
    package = unstable.nix;

    gc = {
      automatic = true;
      dates = "weekly";
      options = lib.mkDefault "--delete-older-than 9d";
    };

    settings = {
      allowed-users = [ "root" ] ++ builtins.attrNames config.users.users;
      auto-optimise-store = true;
      trusted-users = lib.mkAfter [
        "root"
        "yi"
        "nix-builder"
      ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # download-buffer-size = lib.mkDefault (1024 * 1024 * 1024 * 10);

      substituters = [
        # "https://cache.fufu.land"  # TODO: re-enable once nginx proxy is verified
        "http://${yifuwuqiTs}:5000"
        "https://nix-community.cachix.org"
        "https://nixos-rocm.cachix.org"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        "yifuwuqi-cache:k3diDzo5ydrNjlrbZexjTtQxK67HEJYZqGA4r3c7azM="
        "nixos-rocm.cachix.org-1:VEpsf7pRIijjd8csKjFNBGzkBqOmw8H9PRmgAq14LnE"
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };
}
