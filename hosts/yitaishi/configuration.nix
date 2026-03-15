{
  pkgs,
  config,
  inputs,
  ...
}:

let
  desktopEnvironment = "gnome";
  greeter = "gdm";
  mkHome = import ../../modules/home-manager.nix;
in
{
  imports = [
    ./boot.nix
    ./hardware.nix
    ./gaming.nix
    ./networking.nix
    ./addresses.nix
    ../../secrets/sops.nix
    ../../users/users.nix
    ../../modules/common.nix
    ../../modules/nix-settings.nix
    ../../modules/boot-common.nix
    ../../modules/networking/ipv6.nix
    ../../modules/services/samba/client.nix
    ../../modules/packages.nix
    ../../modules/locale.nix
    ../../modules/fonts.nix
    ../../modules/desktop.nix
    ../../modules/services/openssh.nix
  ];

  home-manager = mkHome {
    inherit desktopEnvironment inputs;
    stateVersion = "26.05";
  };

  # environment.systemPackages = [ pkgs.mprisence ];

  desktop.environment = desktopEnvironment;
  desktop.greeter = greeter;

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

  system.stateVersion = "26.05";

  security.polkit.enable = true;

  nixpkgs.config = {
    cudaSupport = false;
    rocmSupport = true;
  };

  hardware = {
    enableRedistributableFirmware = true;

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 100;
    "vm.page-cluster" = 0;
  };
}
