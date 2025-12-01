# WSL-specific configuration module

{
  pkgs,
  inputs,
  ...
}:

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

  nixowos.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      desktopEnvironment = null; # WSL/headless
      inherit inputs;
    };
    users.fufud = import ../../users/home-fufud.nix;
  };

  services.openssh = {
    enable = true;
    listenAddresses = [ ];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
}
