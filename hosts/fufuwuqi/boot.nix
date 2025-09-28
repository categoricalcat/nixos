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

    kernel.sysctl = {
      "kernel.panic" = 10;
      "kernel.panic_on_oops" = 1;
    };

    kernelPackages = pkgs.linuxPackages_latest;

    initrd.availableKernelModules = lib.mkAfter [
      "sd_mod"
    ];

    initrd.kernelModules = lib.mkAfter [ "amdgpu" ];

    kernelModules = lib.mkAfter [
      "amdgpu"
      "wireguard"
      "nft_masq"
    ];
  };
}
