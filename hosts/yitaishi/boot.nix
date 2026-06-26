{
  pkgs,
  lib,
  ...
}:

{
  boot.kernelPackages = pkgs.linuxPackages_zen;
  system.boot.loader.kernelFile = "vmlinuz";

  boot = {
    loader = {
      timeout = 1;
      systemd-boot.configurationLimit = 10;
      systemd-boot.enable = lib.mkForce false;
      grub.enable = false;
    };

    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    initrd.systemd.settings.Manager = {
      DefaultTimeoutStopSec = "10s";
    };
    initrd.systemd.tpm2.enable = false;

    kernelModules = lib.mkAfter [
      "fuse"
      "k10temp"
      "nct6775"
    ];

    kernelParams = [
      "amd_pstate=active"
    ];

    extraModprobeConfig = ''
      options snd_usb_audio implicit_fb=1
    '';
  };

  environment.systemPackages = [ pkgs.sbctl ];
}
