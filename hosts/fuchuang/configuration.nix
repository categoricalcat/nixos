# WSL-specific configuration module

{
  pkgs,
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

  nixowos.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.fufud = import ../../users/home-fufud.nix;
  };

  services.openssh = {
    enable = true;
    listenAddresses = [ ];
  };
}
