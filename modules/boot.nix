{ config, pkgs, ... }:

{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    kernelPackages = pkgs.linuxPackages_latest; # 12.37

    # Serial console on USB
    kernelParams = [ "console=ttyUSB0,115200n8" "console=tty0" ];
  };
}
