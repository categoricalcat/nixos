# Main NixOS Configuration (host: yifuwuqi)

{
  inputs,
  config,
  lib,
  ...
}:

let
  mkHome = import ../../modules/home-manager.nix;
  version = "25.11";
in
{
  imports = [
    ./hardware.nix
    ./addresses.nix
    ./boot.nix
    ./networking.nix
    ./services.nix
    ./joplin.nix
    ../../users/users.nix
    ../../modules/common.nix
    ../../modules/nix-settings.nix
    ../../modules/boot-common.nix
    ../../modules/networking/ipv6.nix
    ../../modules/networking/wireguard-peers.nix
    ../../modules/locale.nix
    ../../modules/fonts.nix
    ../../modules/packages.nix
    ../../modules/services/mariadb.nix
    ../../modules/server-settings.nix
    ../../modules/server-mode.nix
    ../../modules/nix-access-tokens.nix
    ../../modules/virtualisation/podman.nix
    ../../secrets/sops.nix
  ];

  system.stateVersion = version;

  home-manager =
    lib.recursiveUpdate
      (mkHome {
        inherit inputs;
        inherit (config.system) stateVersion;
      })
      {
        users.workd = {
          imports = [ ../../users/home-workd.nix ];
          home.stateVersion = config.system.stateVersion;
        };
      };

  serverMode.headless = true;

  nix.settings = {
    trusted-users = [
      "root"
      "yi"
    ];
    download-buffer-size = 1073741824;
  };

  nix.extraOptions = lib.optionalString config.services.nix-access-tokens.enable ''
    include ${config.sops.templates."nix-access-tokens".path}
  '';

  services.nix-access-tokens.enable = false;

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;

    amdgpu = {
      # amdvlk.enable = true;
    };
  };

  security.tpm2 = {
    enable = true;
  };

  zramSwap = {
    enable = true;
    priority = 100;
    memoryPercent = 100;
    algorithm = "zstd";
  };

  system.autoUpgrade = {
    enable = true;
    flake = inputs.self.outPath;
    flags = [
      "--update-input"
      "nixpkgs"
      "-L" # print build logs
    ];
    dates = "02:00";
    randomizedDelaySec = "45min";
  };
}
