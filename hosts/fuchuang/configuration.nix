# WSL-specific configuration module

{
  pkgs,
  ...
}:

{
  imports = [
    ../../secrets/sops.nix
    ../../modules/packages.nix
    ../../modules/server-mode.nix
    ../../modules/locale.nix
    ../../modules/fonts.nix
    # ../modules/desktop.nix
    ../../users/users.nix
  ];

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

  nixowos.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      desktopEnvironment = null; # WSL/headless
    };
    users.fufud = import ../../users/home-fufud.nix;
  };

  services.openssh = {
    enable = true;
    listenAddresses = [ ];
  };
}
