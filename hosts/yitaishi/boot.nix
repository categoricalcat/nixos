{ pkgs, lib, ... }:

{

  boot = {
    loader = {
      timeout = 1;
      systemd-boot.configurationLimit = 10;
      grub.enable = false;
    };

    kernelModules = lib.mkAfter [
      "fuse"
      "coretemp"
    ];

    kernelParams = [ "amdgpu.ppfeaturemask=0xffffffff" ];

    kernelPackages = pkgs.linuxPackages_latest;
  };
}
