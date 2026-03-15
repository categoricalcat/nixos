# WSL-specific configuration module

{
  pkgs,
  inputs,
  ...
}:

let
  mkHome = import ../../modules/home-manager.nix;
in
{
  imports = [
    ../../modules/services/nfs/client.nix
    ../../secrets/sops.nix
    ../../modules/common.nix
    ../../modules/nix-settings.nix
    ../../modules/packages.nix
    ../../modules/server-mode.nix
    ../../modules/locale.nix
    ../../modules/fonts.nix
    # ../modules/desktop.nix
    ../../users/users.nix
  ];

  system.stateVersion = "26.05";
  wsl.defaultUser = "yi";
  wsl.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking = {
    hostName = "yichuang";
  };

  nixpkgs.config = {
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
