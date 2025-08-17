{ config, pkgs, ... }:
{
  services.dnsmasq = {
    enable = true; # Provides DNS for VPN clients
    settings = {
      interface = [ "wg0" ]; # For security, only serve DNS on VPN
      bind-interfaces = true; # Prevents DNS leaks to other interfaces
      listen-address = [ "10.100.0.1" ]; # VPN server address

      no-resolv = true; # Use our DNS servers instead of system ones

      server = [
        "1.1.1.1" # Primary: Cloudflare for speed
        "8.8.8.8" # Backup: Google for reliability
      ];

      domain = "vpn"; # Makes all VPN clients part of .vpn domain
      local = "/vpn/"; # Keeps VPN DNS queries private

      address = "/fufuwuqi.vpn/10.100.0.1"; # Let VPN clients find server by name

      cache-size = 1000; # Reduces latency for repeated queries

      log-queries = true; # For troubleshooting DNS issues
      log-facility = "/var/log/dnsmasq-vpn.log"; # Keep DNS logs separate

      # Disable hosts file to avoid conflicts
      no-hosts = true;
    };
  };
}
