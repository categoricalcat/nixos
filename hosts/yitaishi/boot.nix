{ pkgs, lib, ... }:

{

  boot = {
    loader = {
      timeout = 1;
      systemd-boot.configurationLimit = 10;
      grub.enable = false;
    };

    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    initrd.kernelModules = [ "amdgpu" ];

    kernelModules = lib.mkAfter [
      "fuse"
      "k10temp"
      "nct6775"
    ];

    kernelParams = [
      "amdgpu.ppfeaturemask=0xffffffff"
      "amd_pstate=active"
    ];

    kernelPackages = pkgs.linuxPackages_latest;
  };

  boot.loader.systemd-boot.enable = lib.mkForce false;

  environment.systemPackages = [ pkgs.sbctl ];
}
