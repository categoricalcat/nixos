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

    kernelPackages = pkgs.linuxPackages_latest;
  };
}
