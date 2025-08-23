{ upstreamDnsServers, ... }:
{
  services.dnsmasq = {
    enable = true; # Provides DNS for VPN clients
    settings = {
      interface = [
        "wg0"
        "bond0"
      ]; # Serve DNS on VPN and LAN
      bind-dynamic = true; # Track interfaces dynamically and bind when addresses appear
      # Explicitly listen on our IPv6 and IPv4 addresses
      listen-address = [
        "2804:41fc:8030:ace1::1"
        "10.100.0.1"
      ];

      no-resolv = true; # Use our DNS servers instead of system ones

      # Forward only to public upstream resolvers
      server = upstreamDnsServers;

      # Query all upstreams in parallel to avoid IPv6-only timeouts
      all-servers = true;

      # Avoid fragmentation/PMTU issues over IPv6
      edns-packet-max = 1232;

      domain = "vpn"; # Makes all VPN clients part of .vpn domain
      local = "/vpn/"; # Keeps VPN DNS queries private

      address = [
        "/fufuwuqi.vpn/2804:41fc:8030:ace1::1"
        "/fufuwuqi.vpn/10.100.0.1"
      ];

      cache-size = 1000; # Reduces latency for repeated queries

      log-queries = true; # For troubleshooting DNS issues
      log-facility = "/var/log/dnsmasq-vpn.log"; # Keep DNS logs separate

      # Disable hosts file to avoid conflicts
      no-hosts = true;
    };
  };
  # Ensure dnsmasq starts after network devices are present
  systemd.services.dnsmasq = {
    after = [
      "sys-subsystem-net-devices-wg0.device"
      "sys-subsystem-net-devices-bond0.device"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
  };
}
