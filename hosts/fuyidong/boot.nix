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
    };

    kernelPackages = pkgs.linuxPackages;
  };
}
