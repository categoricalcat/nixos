{ lib, ... }:

{
  imports = [
    ./lix.nix
  ];

  _module.args.allAddresses = import ./addresses.nix;
  environment.defaultPackages = lib.mkForce [ ];
  nixpkgs.config.allowUnfree = true;
  programs.nix-ld.enable = true;
}
