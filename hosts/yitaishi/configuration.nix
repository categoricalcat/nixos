{
  pkgs,
  inputs,
  lib,
  global,
  ...
}:

let
  greeter = "dms";
  monitors = [
    {
      name = "GSM-0x000083cb";
      connector = "DP-3";
      mode = "2560x1080@74.991";
      position = {
        x = 0;
        y = 2160;
      };
      scale = 1.0;
      vrr = true;
    }
    {
      name = "AUS-S2LMQS085997";
      connector = "DP-1";
      mode = "1920x1080@239.760";
      position = {
        x = 2560;
        y = 2160;
      };
      scale = 1.0;
      hdr = true;
    }
    {
      name = "GSM-0x01010101";
      connector = "HDMI-A-1";
      mode = "3840x2160@120.000";
      position = {
        x = 640;
        y = 0;
      };
      scale = 1.0;
      hdr = true;
    }
  ];
  mkHome = import ../../modules/home-manager.nix;
  inherit (global) version;
in
{
  imports = [
    ./boot.nix
    ./power.nix
    ./gaming.nix
    ./hardware.nix
    ./graphics.nix
    ./services.nix
    ./addresses.nix
    ./networking.nix
    ../../users/users.nix
    ../../secrets/sops.nix
    ../../modules/fonts.nix
    ../../modules/fido2.nix
    ../../modules/audio
    ../../modules/common.nix
    ../../modules/gaming.nix
    ../../modules/locale.nix
    ../../modules/packages
    ../../modules/packages/dev.nix
    ../../modules/packages/network.nix
    ../../modules/desktop.nix
    ../../modules/boot-common.nix
    ../../modules/hardware/fanatec
    ../../modules/nix-settings.nix
    ../../modules/networking/ipv6.nix
    ../../modules/networking/sysctl-base.nix
    ../../modules/services/ssh
    ../../modules/distributed-builds.nix
    ../../modules/services/samba/client.nix
  ];

  security.fido2.enable = true;
  systemd.tpm2.enable = false;

  system.stateVersion = version;

  host = {
    desktopEnvironment = "mango";
    desktopShell = "dms";
    barScreenPreferences = [ "DP-1" ];
    vr = true;
    workd = true;
  };

  home-manager = mkHome {
    inherit inputs monitors;
    keyboardProfile = "us";
    stateVersion = global.homeVersion;
    enableWorkd = true;
  };

  desktop = {
    inherit greeter monitors;
    keyboard = "us";
  };

  environment.systemPackages = [ pkgs.xclip ];

  security.polkit.enable = true;

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = lib.mkForce 1;

    # Avoid aggressive watermark boosting that can over-reclaim with zram.
    "vm.watermark_boost_factor" = 0;

    # Keep the kernel's free-memory watermark scaling conservative.
    "vm.watermark_scale_factor" = 100;

    # Swap individual pages instead of clustering reads around zram.
    "vm.page-cluster" = 0;

    # Network tuning for better latency and throughput (streaming/gaming)
    "net.core.default_qdisc" = "cake";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  boot.kernelModules = [ "tcp_bbr" ];
}
