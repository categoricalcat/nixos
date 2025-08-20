{ dnsServers, ... }:
{
  services.dnsmasq = {
    enable = true; # Provides DNS for VPN clients
    settings = {
      interface = [
        "wg0"
        "bond0"
      ]; # Serve DNS on VPN and LAN
      bind-interfaces = true; # Prevents DNS leaks to other interfaces
      # No listen-address: bind on all addresses of listed interfaces

      no-resolv = true; # Use our DNS servers instead of system ones

      # Use the same DNS servers as defined in networking.nix
      server = dnsServers;

      domain = "vpn"; # Makes all VPN clients part of .vpn domain
      local = "/vpn/"; # Keeps VPN DNS queries private

      address = [
        "/fufuwuqi.vpn/fd00:100::1"
        "/fufuwuqi.vpn/10.100.0.1"
      ];

      cache-size = 1000; # Reduces latency for repeated queries

      log-queries = true; # For troubleshooting DNS issues
      log-facility = "/var/log/dnsmasq-vpn.log"; # Keep DNS logs separate

      # Disable hosts file to avoid conflicts
      no-hosts = true;
    };
  };
}
