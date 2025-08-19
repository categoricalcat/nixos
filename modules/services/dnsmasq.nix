_: {
  services.dnsmasq = {
    enable = true; # Provides DNS for VPN clients
    settings = {
      interface = [ "wg0" "bond0" ]; # Serve DNS on VPN and LAN
      bind-interfaces = true; # Prevents DNS leaks to other interfaces
      # No listen-address: bind on all addresses of listed interfaces

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
