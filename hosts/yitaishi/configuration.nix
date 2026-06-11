{
  config,
  pkgs,
  inputs,
  lib,
  global,
  ...
}:

let
  desktopEnvironment = "gnome";
  desktopShell = "none";
  greeter = "tuigreet";
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
    ../../modules/audio.nix
    ../../modules/common.nix
    ../../modules/locale.nix
    ../../modules/packages.nix
    ../../modules/desktop.nix
    ../../modules/boot-common.nix
    ../../modules/hardware/fanatec
    ../../modules/nix-settings.nix
    ../../modules/networking/ipv6.nix
    ../../modules/services/openssh.nix
    ../../modules/distributed-builds.nix
    ../../modules/services/tailscale.nix
    ../../modules/services/samba/client.nix
  ];

  security.fido2.enable = true;
  systemd.tpm2.enable = false;

  system.stateVersion = version;

  home-manager = mkHome {
    inherit inputs desktopEnvironment;
    stateVersion = global.homeVersion;
  };

  sops.secrets."tokens/deepseek" = {
    owner = config.users.users.yi.name;
    inherit (config.users.users.yi) group;
    mode = "0400";
  };

  desktop = {
    environment = desktopEnvironment;
    shell = desktopShell;
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

  # services.xserver.resolutions = [
  #   {
  #     x = 3840;
  #     y = 2160;
  #   }
  #   {
  #     x = 2560;
  #     y = 1440;
  #   }
  #   {
  #     x = 1920;
  #     y = 1080;
  #   }
  # ];

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
