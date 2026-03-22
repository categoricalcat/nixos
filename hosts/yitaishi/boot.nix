{ pkgs, lib, ... }:

{

  boot = {
    loader = {
      timeout = 1;
      systemd-boot.configurationLimit = 10;
      grub.enable = false;
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
}
