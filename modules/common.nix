{ pkgs, lib, ... }:

{
  _module.args.allAddresses = import ./addresses.nix;

  imports = [
    ./nix-ld.nix
    ./server-mode.nix
    ./services/chrony.nix
    ./services/kmscon.nix
  ];

  nix.package = lib.mkForce pkgs.lix;
  nixpkgs.config.allowUnfree = true;
  environment.defaultPackages = lib.mkForce [ ];
}
