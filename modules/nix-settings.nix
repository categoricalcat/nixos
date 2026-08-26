{
  config,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ./services/attic/client.nix
  ];

  environment.etc = lib.mapAttrs' (name: value: {
    name = "nix/inputs/${name}";
    value.source = value.outPath;
  }) (lib.filterAttrs (name: _: name != "self") inputs);

  nix = {
    registry = lib.mapAttrs (_: flake: { inherit flake; }) inputs;
    nixPath = [ "/etc/nix/inputs" ];

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
      accept-flake-config = false;
      # download-buffer-size = lib.mkDefault (1024 * 1024 * 1024 * 10);

      substituters = [
        "https://nix-community.cachix.org"
        "https://nixos-rocm.cachix.org"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        "nixos-rocm.cachix.org-1:VEpsf7pRIijjd8csKjFNBGzkBqOmw8H9PRmgAq14LnE"
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };
}
