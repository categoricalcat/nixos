{ pkgs, lib, ... }:

{

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 15;
      };
      efi.canTouchEfiVariables = true;
    };

    kernelModules = lib.mkAfter [ "coretemp" ];

    kernel.sysctl = {
      "kernel.panic" = 10;
      "kernel.panic_on_oops" = 1;
      "vm.swappiness" = 80;
    };

    kernelPackages = pkgs.linuxPackages;
  };
}
