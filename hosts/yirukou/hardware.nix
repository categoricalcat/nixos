{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" ];
  # boot.initrd.kernelModules = [ ];
  # boot.kernelModules = [ "kvm-intel" ];
  # boot.extraModulePackages = [ ];

  # fileSystems."/" = {
  #   device = "/dev/disk/by-uuid/...";
  #   fsType = "ext4";
  #   options = [ "noatime" "nodiratime" ];
  # };

  # fileSystems."/boot" = {
  #   device = "/dev/disk/by-uuid/...";
  #   fsType = "vfat";
  #   options = [ "umask=0077" ];
  # };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.enableRedistributableFirmware = lib.mkDefault true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
