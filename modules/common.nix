{
  pkgs,
  lib,
  inputs,
  config,
  ...
}:

{
  _module.args.allAddresses = import ./addresses.nix;

  imports = [
    ./nix-ld.nix
    ./host.nix
    ./server-mode.nix
    ./services/ai/opencode.nix
    ./services/chrony.nix
    ./services/kmscon.nix
  ];

  home-manager.sharedModules = [
    {
      inherit (config) host serverMode;
    }
  ];

  nix.package = lib.mkForce pkgs.lix;
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = import ../nix/overlays.nix { inherit inputs; };
  environment.defaultPackages = lib.mkForce [ ];
}
