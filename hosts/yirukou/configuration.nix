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
    ./hardware.nix
    ./addresses.nix
    ./networking.nix
    ./services.nix
    ../../modules/common.nix
    ../../modules/locale.nix
    ../../modules/server-mode.nix
    ../../users/users.nix
    ../../secrets/sops.nix
  ];

  system.stateVersion = global.version;

  home-manager = mkHome {
    inherit inputs;
    stateVersion = global.homeVersion;
  };

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 9d";
    };
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
    };
  };

  nixpkgs.hostPlatform = "x86_64-linux";
}
