{ lib, ... }:

{
  environment.defaultPackages = lib.mkForce [ ];
  nixpkgs.config.allowUnfree = true;
  programs.nix-ld.enable = true;
}
