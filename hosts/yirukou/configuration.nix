{
  inputs,
  global,
  ...
}:

let
  mkHome = import ../../modules/home-manager.nix;
in
{
  imports = [
    ./boot.nix
    ./services.nix
    ./hardware.nix
    ./addresses.nix
    ./networking.nix
    ../../users/users.nix
    ../../secrets/sops.nix
    ../../modules/common.nix
    ../../modules/locale.nix
    ../../modules/server-mode.nix
    ../../modules/nix-settings.nix
    ../../modules/server-settings.nix
    ../../modules/packages.nix
  ];

  system.stateVersion = global.version;

  home-manager = mkHome {
    inherit inputs;
    stateVersion = global.homeVersion;
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  zramSwap = {
    enable = true;
    priority = 100;
    memoryPercent = 100;
    algorithm = "zstd";
  };
}
