# Main NixOS Configuration (host: yifuwuqi)

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
    ./hardware.nix
    ./boot.nix
    ./networking.nix
    ./services.nix
    ../../users/users.nix
    ../../modules/common.nix
    ../../modules/stylix.nix
    ../../modules/nix-settings.nix
    ../../modules/distributed-builds.nix
    ../../modules/boot-common.nix
    ../../modules/networking/ipv6.nix
    ../../modules/locale.nix
    ../../modules/packages
    ../../modules/packages/network.nix
    ../../modules/services/postgresql.nix
    ../../modules/server-settings.nix
    ../../modules/nix-access-tokens.nix
    ../../modules/virtualisation/podman.nix
    ../../secrets/sops.nix
    ../../modules/fido2.nix
    ../../packages/dev-certs/module.nix
  ];

  security.fido2.enable = true;

  system.stateVersion = global.version;

  home-manager = mkHome {
    inherit inputs;
    stateVersion = global.homeVersion;
    enableWorkd = true;
  };

  host.workd = true;

  services.nix-access-tokens.enable = true;

  yi.ssh.permitRootKeyLogin = true;

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;

    amdgpu = {
      # amdvlk.enable = true;
    };
  };

  # Mesa main (chaotic-nyx, binary-cached) as the default driver set: the
  # llama.cpp Vulkan backend runs on its RADV ICD (gfx1035). The module's
  # fallbackSpecialisation keeps a stable-mesa boot entry for recovery from
  # upstream regressions.
  chaotic.mesa-git.enable = true;

  system.nixos.tags = [ "mesa-git" ];

  security.tpm2 = {
    enable = true;
  };

  zramSwap = {
    enable = true;
    priority = 100;
    memoryPercent = 100;
    algorithm = "zstd";
  };

  # Measured contention fixes (docs/src/hardware/new-compute-host-research.md):
  # CI and build bursts starved interactive and media load, so they yield CPU
  # and disk weight under contention, and per-build parallelism is capped to 4
  # threads on this 8C/16T box so single derivations cannot saturate all cores.
  nix.settings.cores = 4;

  systemd.services.nix-daemon.serviceConfig = {
    CPUWeight = 50;
    IOWeight = 50;
  };

}
