# Boot configuration module

{ config, pkgs, ... }:

{
  # Bootloader configuration
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
}
