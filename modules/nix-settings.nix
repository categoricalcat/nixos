{
  config,
  lib,
  pkgs,
  inputs,
  allAddresses,
  ...
}:

let
  attic = allAddresses.hosts.yifuwuqi.services.attic;

in
{
  environment.etc = lib.mapAttrs' (name: value: {
    name = "nix/inputs/${name}";
    value.source = value.outPath;
  }) (lib.filterAttrs (name: _: name != "self") inputs);

  nix = {
    registry = lib.mapAttrs (_: flake: { inherit flake; }) inputs;
    nixPath = [ "/etc/nix/inputs" ];

    package = pkgs.nix;

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
        "https://${attic.domain}/${attic.cacheName}"
        "https://nix-community.cachix.org"
        "https://nixos-rocm.cachix.org"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        # Replace after bootstrap: attic cache info <cache-name>
        "${attic.cacheName}:jxjweC50pjTzEjmGv2uoxeTBTep9gfVnv8IaGgCKYE8="
        "nixos-rocm.cachix.org-1:VEpsf7pRIijjd8csKjFNBGzkBqOmw8H9PRmgAq14LnE"
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };
}
