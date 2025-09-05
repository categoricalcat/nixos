{ pkgs, lib, ... }:

{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
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
