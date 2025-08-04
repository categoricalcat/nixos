# WSL-specific configuration module

{
  config,
  pkgs,
  lib,
  ...
}:

{
  system.stateVersion = "25.11";
  wsl.defaultUser = "fufud";
  wsl.enable = true;

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
}
