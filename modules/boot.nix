{ pkgs, ... }:

{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    kernelPackages = pkgs.linuxPackages_latest;

    # Serial console on USB
    kernelParams = [
      "console=ttyUSB0,115200n8"
      "console=tty0"
    ];

    kernel.sysctl = {
      # Dual-stack setup - enable both IPv4 and IPv6 forwarding
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;

      # WireGuard VPN specific settings
      "net.ipv4.conf.wg0.forwarding" = 1;
      "net.ipv6.conf.wg0.forwarding" = 1;
      "net.ipv6.conf.wg0.accept_ra" = 2; # Accept RAs even when forwarding is enabled
    };
  };
}
