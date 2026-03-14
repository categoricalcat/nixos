# TODO: Replace this file with the output of `nixos-generate-config --show-hardware-config`
# run on the actual yitaishi machine.
{
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # boot.initrd.availableKernelModules = [ ];
  # boot.initrd.kernelModules = [ ];
  # boot.kernelModules = [ ];
  # boot.extraModulePackages = [ ];

  # fileSystems."/" = {
  #   device = "/dev/disk/by-uuid/CHANGE-ME";
  #   fsType = "ext4";
  # };

  # fileSystems."/boot" = {
  #   device = "/dev/disk/by-uuid/CHANGE-ME";
  #   fsType = "vfat";
  #   options = [
  #     "fmask=0077"
  #     "dmask=0077"
  #   ];
  # };

  # swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
