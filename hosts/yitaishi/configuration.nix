{
  pkgs,
  inputs,
  lib,
  global,
  ...
}:

let
  greeter = "ly";
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
    ../../modules/packages.nix
    ../../modules/desktop.nix
    ../../modules/boot-common.nix
    ../../modules/hardware/fanatec
    ../../modules/nix-settings.nix
    ../../modules/networking/ipv6.nix
    ../../modules/networking/sysctl-base.nix
    ../../modules/services/ssh
    ../../modules/distributed-builds.nix
    # ../../modules/services/tailscale.nix
    ../../modules/services/samba/client.nix
  ];

  security.fido2.enable = true;
  systemd.tpm2.enable = false;

  system.stateVersion = version;

  host = {
    desktopEnvironment = "gnome";
    vr = true;
    workd = true;
  };

  home-manager = mkHome {
    inherit inputs;
    keyboardProfile = "us";
    stateVersion = global.homeVersion;
    enableWorkd = true;
  };

  desktop = {
    inherit greeter;
    keyboard = "us";
    monitors = [
      {
        name = "GSM-0x000083cb";
        mode = "2560x1080@74.991";
        position = {
          x = 0;
          y = 2160;
        };
        scale = 1.0;
      }
      {
        name = "AUS-S2LMQS085997";
        mode = "1920x1080@239.760";
        position = {
          x = 2560;
          y = 2160;
        };
        scale = 1.0;
      }
      {
        name = "GSM-0x01010101";
        mode = "3840x2160@120.000";
        position = {
          x = 640;
          y = 0;
        };
        scale = 1.0;
      }
    ];
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
