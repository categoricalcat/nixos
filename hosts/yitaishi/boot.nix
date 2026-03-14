{ pkgs, lib, ... }:

{

  boot = {
    loader = {
      timeout = 1;
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      grub.enable = false;
      efi.canTouchEfiVariables = true;
    };

    kernelModules = lib.mkAfter [
      "fuse"
      "coretemp"
    ];

    kernel.sysctl = {
      "kernel.panic" = 10;
      "kernel.panic_on_oops" = 1;
    };

    kernelPackages = pkgs.linuxPackages_latest;
  };
}
