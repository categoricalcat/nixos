{
  pkgs,
  inputs,
  lib,
  global,
  allAddresses,
  ...
}:

let
  greeter = "dms";
  monitors = [
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
  mkHome = import ../../modules/home-manager.nix;
in
{
  imports = [
    ./boot.nix
    ./hardware.nix
    ./power.nix
    ./networking.nix
    ./addresses.nix
    ../../secrets/sops.nix
    ../../users/users.nix
    ../../modules/fido2.nix
    ../../modules/fonts.nix
    ../../modules/common.nix
    ../../modules/gaming.nix
    ../../modules/locale.nix
    ../../modules/desktop.nix
    ../../modules/packages
    ../../modules/packages/dev.nix
    ../../modules/packages/network.nix
    ../../modules/boot-common.nix
    ../../modules/nix-settings.nix
    ../../modules/services/tlp.nix
    ../../modules/networking/ipv6.nix
    ../../modules/services/ssh
    ../../modules/distributed-builds.nix
    ../../modules/services/lan-mouse.nix
    ../../modules/services/tailscale.nix
    # ../../modules/services/netbird.nix
    ../../modules/services/tpm-fido2.nix
    ../../modules/services/samba/client.nix
    # ../../modules/services/power-profiles-daemon.nix
  ];

  system.stateVersion = global.version;

  host = {
    desktopEnvironment = "niri";
    desktopShell = "dms";
    workd = true;
  };

  home-manager = mkHome {
    inherit
      inputs
      monitors
      ;
    keyboardProfile = "br";
    stateVersion = global.homeVersion;
    enableWorkd = true;
  };

  desktop = {
    inherit greeter;
    keyboard = "br";
    inherit monitors;
  };

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
  security = {
    fido2.enable = true;
    tpm-fido2.enable = true;
    polkit.enable = true;
    pam.services = {
      login.fprintAuth = lib.mkDefault true;
      gdm-fingerprint.fprintAuth = true;
      sudo.fprintAuth = true;
      polkit-1.u2fAuth = true;
    };
  };

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
    "vm.swappiness" = 180;

    # Avoid aggressive watermark boosting that can over-reclaim with zram.
    "vm.watermark_boost_factor" = 0;

    # Keep the kernel's free-memory watermark scaling conservative.
    "vm.watermark_scale_factor" = 100;

    # Swap individual pages instead of clustering reads around zram.
    "vm.page-cluster" = 0;
  };

  services.lan-mouse.settings = {
    left = {
      hostname = "${allAddresses.hosts.yitaishi.hostName}.${allAddresses.hosts.yitaishi.network.vpn.domain}";
      activate_on_startup = true;
      ips = [ allAddresses.hosts.yitaishi.network.vpn.ipv4.host ];
    };
    authorized_fingerprints = {
      # "yitaishi-fingerprint" = "yitaishi";
    };
  };

  yi.tailscale = {
    routingMode = "client";
    exitNodeHost = allAddresses.hosts.yirukou.network.tailscale.ipv4.host;
  };
}
