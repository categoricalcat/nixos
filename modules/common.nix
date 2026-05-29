{ lib, ... }:

{
  imports = [
    ./lix.nix
    ./nix-ld.nix
    ./services/chrony.nix
  ];

  _module.args.allAddresses = import ./addresses.nix;
  environment.defaultPackages = lib.mkForce [ ];
  nixpkgs.config.allowUnfree = true;
}
