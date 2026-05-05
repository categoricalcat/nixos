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
  greeter = "tuigreet";
  mkHome = import ../../modules/home-manager.nix;
  inherit (global) version;
in
{
  imports = [
    ./boot.nix
    ./hardware.nix
    ./gaming.nix
    ./networking.nix
    ./power.nix
    ./addresses.nix
    ./services.nix
    ../../secrets/sops.nix
    ../../users/users.nix
    ../../modules/common.nix
    ../../modules/hardware/fanatec
    ../../modules/nix-settings.nix
    ../../modules/distributed-builds.nix
    ../../modules/boot-common.nix
    ../../modules/networking/ipv6.nix
    ../../modules/services/samba/client.nix
    ../../modules/packages.nix
    ../../modules/locale.nix
    ../../modules/fonts.nix
    ../../modules/desktop.nix
    ../../modules/services/openssh.nix
    ../../modules/services/tailscale.nix
    ../../modules/fido2.nix
    ../../modules/audio.nix
  ];

  security.fido2.enable = true;

  system.stateVersion = version;

  home-manager =
    lib.recursiveUpdate
      (mkHome {
        inherit inputs desktopEnvironment;
        stateVersion = global.homeVersion;
      })
      {
        users.yi.dconf.settings = {
          "org/gnome/desktop/session" = {
            idle-delay = inputs.home-manager.lib.hm.gvariant.mkUint32 0;
          };

          "org/gnome/settings-daemon/plugins/power" = {
            idle-dim = false;
            sleep-inactive-ac-timeout = 0;
            sleep-inactive-ac-type = "nothing";
            sleep-inactive-battery-timeout = 0;
            sleep-inactive-battery-type = "nothing";
          };
        };

        users.workd = {
          imports = [ ../../users/home/workd.nix ];
          home.stateVersion = global.homeVersion;
        };
      };

  sops.secrets."tokens/deepseek" = {
    owner = config.users.users.yi.name;
    inherit (config.users.users.yi) group;
    mode = "0400";
  };

  desktop.environment = desktopEnvironment;
  desktop.greeter = greeter;

  console.keyMap = "us-acentos";
  services.xserver.xkb = {
    layout = "us";
    variant = "intl";
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
    "vm.swappiness" = 100;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 100;
    "vm.page-cluster" = 0;
  };
}
