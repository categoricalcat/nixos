{
  pkgs,
  inputs,
  lib,
  global,
  ...
}:

let
  desktopEnvironment = "niri";
  desktopShell = "dms";
  greeter = "tuigreet";
  mkHome = import ../../modules/home-manager.nix;
in
{
  imports = [
    ./boot.nix
    ./hardware.nix
    ./power.nix
    ./gaming.nix
    ./networking.nix
    ./addresses.nix
    ../../secrets/sops.nix
    ../../users/users.nix
    ../../modules/fido2.nix
    ../../modules/fonts.nix
    ../../modules/common.nix
    ../../modules/locale.nix
    ../../modules/desktop.nix
    ../../modules/packages.nix
    ../../modules/boot-common.nix
    ../../modules/nix-settings.nix
    ../../modules/services/tlp.nix
    ../../modules/networking/ipv6.nix
    ../../modules/services/openssh.nix
    ../../modules/distributed-builds.nix
    ../../modules/services/lan-mouse.nix
    ../../modules/services/tailscale.nix
    ../../modules/services/samba/client.nix
    # ../../modules/services/power-profiles-daemon.nix
    ../../modules/services/netbird.nix
  ];

  security.fido2.enable = true;

  system.stateVersion = global.version;

  home-manager = mkHome {
    inherit inputs desktopEnvironment;
    stateVersion = global.homeVersion;
  };

  desktop.environment = desktopEnvironment;
  desktop.shell = desktopShell;
  desktop.greeter = greeter;
  desktop.keyboard = "br";
  desktop.monitors = [
    {
      name = "eDP-1";
      mode = "2880x1800@60";
      scale = 1.5;
      transform = "normal";
      position = {
        x = 1280;
        y = 0;
      };
    }
  ];

  security.polkit.enable = true;

  nixpkgs.config = {
    cudaSupport = false;
    rocmSupport = false;
  };

  # distributedBuilds = {
  #   enable = true;
  #   role = "client";
  # };

  nix = {
    settings = {
      trusted-users = [
        "@wheel"
      ];
    };
  };

  services.fprintd.enable = true;
  security.pam.services.login.fprintAuth = lib.mkDefault true;
  security.pam.services.gdm-fingerprint.fprintAuth = true;
  security.pam.services.sudo.fprintAuth = true;
  security.pam.services.polkit-1.u2fAuth = true;

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
    intel-gpu-tools.enable = true;

    bluetooth = {
      enable = true;
      powerOnBoot = false;
    };

    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-compute-runtime
        vpl-gpu-rt
        intel-media-driver
      ];
    };
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 100;
  };

  boot.kernel.sysctl = {
    # Prefer compressed zram swap on this workstation.
    "vm.swappiness" = 100;

    # Avoid aggressive watermark boosting that can over-reclaim with zram.
    "vm.watermark_boost_factor" = 0;

    # Keep the kernel's free-memory watermark scaling conservative.
    "vm.watermark_scale_factor" = 100;

    # Swap individual pages instead of clustering reads around zram.
    "vm.page-cluster" = 0;
  };

  services.lan-mouse.settings = {
    authorized_fingerprints = {
      # "yitaishi-fingerprint" = "yitaishi";
    };
  };
}
