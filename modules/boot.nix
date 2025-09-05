{ pkgs, lib, ... }:

{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    kernelPackages = pkgs.linuxPackages_latest;

    # Additional hardware-specific kernel modules
    initrd.availableKernelModules = lib.mkAfter [
      "usb_storage"
      "usbhid"
      "sd_mod"
    ];

    initrd.kernelModules = lib.mkAfter [ "amdgpu" ];

    kernelModules = lib.mkAfter [
      "amdgpu"
      "wireguard"
      "nft_masq"
    ];

    # Serial console on USB
    kernelParams = [
      "console=ttyUSB0,115200n8"
      "console=tty0"
    ];

  };
}
