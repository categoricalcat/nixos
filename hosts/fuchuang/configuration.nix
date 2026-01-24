# WSL-specific configuration module

{
  pkgs,
  inputs,
  lib,
  ...
}:

let
  mkHome = import ../../modules/home-manager.nix;
in
{
  imports = [
    ../../modules/services/nfs/client.nix
    ../../secrets/sops.nix
    ../../modules/packages.nix
    ../../modules/server-mode.nix
    ../../modules/locale.nix
    ../../modules/fonts.nix
    # ../modules/desktop.nix
    ../../users/users.nix
  ];

  system.stateVersion = "26.05";
  wsl.defaultUser = "fufud";
  wsl.enable = true;

  environment.defaultPackages = lib.mkForce [ ];

  networking = {
    hostName = "fuchuang";
  };

  programs.nix-ld.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  nixpkgs.config = {
    allowUnfree = true;
    cudaSupport = false;
    rocmSupport = true;
  };

  home-manager = mkHome {
    inherit inputs;
    stateVersion = "26.05";
  };

  services.openssh = {
    enable = true;
    listenAddresses = [ ];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
}
