# Main NixOS Configuration (host: fufuwuqi)

{
  inputs,
  config,
  lib,
  ...
}:

{
  imports = [
    ./hardware.nix
    ../../modules/networking/wireguard-peers.nix
    ./addresses.nix
    ./boot.nix
    ../../modules/locale.nix
    ../../modules/fonts.nix
    ../../users/users.nix
    ../../modules/packages.nix
    ./networking.nix
    ./services.nix
    ./joplin.nix
    ./mariadb.nix
    # ../../modules/desktop.nix
    ../../modules/server-settings.nix
    ../../modules/server-mode.nix
    ../../secrets/sops.nix
  ];

  serverMode.headless = true;

  nix.settings = {
    trusted-users = [
      "root"
      "fufud"
    ];

    experimental-features = [
      "nix-command"
      "flakes"
    ];
    download-buffer-size = 1073741824;

    substituters = [
      "https://nix-community.cachix.org"
      "https://nixos-rocm.cachix.org"
      "https://cache.nixos.org/"
    ];
    trusted-public-keys = [
      "nixos-rocm.cachix.org-1:VEpsf7pRIijjd8csKjFNBGzkBqOmw8H9PRmgAq14LnE"
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  nix.extraOptions = lib.optionalString config.services.nix-access-tokens.enable ''
    include ${config.sops.templates."nix-access-tokens".path}
  '';

  services.nix-access-tokens.enable = false;

  nixpkgs.config = {
    allowUnfree = true;
    cudaSupport = false;
    rocmSupport = true;
    rocmTargets = [ "gfx1035" ];
  };

  system.stateVersion = "25.11";

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
    graphics = {
      enable = true;
      enable32Bit = true;
    };

    amdgpu = {
      opencl.enable = true;
      # amdvlk.enable = true;
    };
  };

  security.tpm2 = {
    enable = true;
  };

  nixowos.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      desktopEnvironment = null; # server/headless
      inherit inputs;
    };
    users.fufud = import ../../users/home-fufud.nix;
    users.workd = import ../../users/home-workd.nix;
  };
}
