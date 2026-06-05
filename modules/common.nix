{ lib, ... }:

{
  imports = [
    ./lix.nix
    ./nix-ld.nix
    ./services/chrony.nix
    ./services/kmscon.nix
  ];

  services.kmscon.enable = true;

  _module.args.allAddresses = import ./addresses.nix;
  environment.defaultPackages = lib.mkForce [ ];
  nixpkgs.config.allowUnfree = true;
}
