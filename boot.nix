# Boot configuration module

{ config, pkgs, ... }:

{

  boot = {
    # Bootloader configuration
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    kernelPackages = pkgs.linuxPackages_latest; # 12.37
  };

  # Option 2: Use the LTS (Long Term Support) kernel
  # boot.kernelPackages = pkgs.linuxPackages;

  # Option 3: Use a specific kernel version
  # boot.kernelPackages = pkgs.linuxPackages_6_11;  # 6.11.x series
  # boot.kernelPackages = pkgs.linuxPackages_6_10;  # 6.10.x series
  # boot.kernelPackages = pkgs.linuxPackages_6_6;   # 6.6.x LTS series
  # boot.kernelPackages = pkgs.linuxPackages_6_1;   # 6.1.x LTS series

  # Option 4: Use the Zen kernel (optimized for desktop)
  # boot.kernelPackages = pkgs.linuxPackages_zen;

  # Option 5: Use the hardened kernel (security-focused)
  # boot.kernelPackages = pkgs.linuxPackages_hardened;

  # Option 6: Use the real-time kernel (for low-latency applications)
  # boot.kernelPackages = pkgs.linuxPackages_rt;

  # Currently using default kernel from NixOS 25.05
  # Uncomment one of the above options to change kernel version
}
