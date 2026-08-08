# Main NixOS Configuration (host: yifuwuqi)

{
  inputs,
  config,
  lib,
  global,
  ...
}:

let
  mkHome = import ../../modules/home-manager.nix;
in
{
  imports = [
    ./hardware.nix
    ./addresses.nix
    ./boot.nix
    ./networking.nix
    ./services.nix
    ./portainer.nix
    ../../users/users.nix
    ../../modules/common.nix
    ../../modules/stylix.nix
    ../../modules/nix-settings.nix
    ../../modules/distributed-builds.nix
    ../../modules/boot-common.nix
    ../../modules/networking/ipv6.nix
    ../../modules/locale.nix
    ../../modules/fonts.nix
    ../../modules/packages.nix
    ../../modules/services/postgresql.nix
    ../../modules/server-settings.nix
    ../../modules/nix-access-tokens.nix
    ../../modules/virtualisation/podman.nix
    ../../secrets/sops.nix
    ../../modules/fido2.nix
  ];

  security.fido2.enable = true;

  system.stateVersion = global.version;

  home-manager = mkHome {
    inherit inputs;
    stateVersion = global.homeVersion;
  };

  serverMode.headless = true;

  sops.secrets."tokens/deepseek" = {
    owner = config.users.users.yi.name;
    inherit (config.users.users.yi) group;
    mode = "0400";
  };

  nix.settings = {
    trusted-users = [
      "@wheel"
    ];
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

}
