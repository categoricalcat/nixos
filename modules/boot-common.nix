{
  pkgs,
  lib,
  ...
}:

{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    kernel.sysctl = {
      # Reboot ten seconds after a kernel panic instead of staying wedged.
      "kernel.panic" = 10;

      # Treat kernel oopses as panics so the automatic reboot path is used.
      "kernel.panic_on_oops" = 1;
    };
  };

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
}
