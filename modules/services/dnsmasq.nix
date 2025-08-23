{ addresses, upstreamDnsServers, ... }:
{
  services.dnsmasq = {
    enable = true; # Provides DNS for VPN clients
    settings = {
      interface = [
        addresses.network.vpn.interface
        addresses.network.lan.interface
      ]; # Serve DNS on VPN and LAN
      bind-dynamic = true; # Track interfaces dynamically and bind when addresses appear
      # Explicitly listen on our IPv6 and IPv4 addresses
      listen-address = [
        addresses.network.vpn.ipv6.host
        addresses.network.vpn.ipv4.host
        addresses.network.lan.ipv6.host
        addresses.network.lan.ipv4.host
      ];

      no-resolv = true; # Use our DNS servers instead of system ones

      # Forward only to public upstream resolvers
      server = upstreamDnsServers;

      # Query all upstreams in parallel to avoid IPv6-only timeouts
      all-servers = true;

      # Avoid fragmentation/PMTU issues over IPv6
      edns-packet-max = 1232;

      inherit (addresses.dns) domain; # Makes all VPN clients part of .vpn domain
      local = "/${addresses.dns.domain}/"; # Keeps VPN DNS queries private

      address = [
        "/${addresses.hostName}.${addresses.dns.domain}/${addresses.network.vpn.ipv6.host}"
        "/${addresses.hostName}.${addresses.dns.domain}/${addresses.network.vpn.ipv4.host}"
        "/${addresses.hostName}.${addresses.dns.domain}/${addresses.network.lan.ipv6.host}"
        "/${addresses.hostName}.${addresses.dns.domain}/${addresses.network.lan.ipv4.host}"
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
      "sys-subsystem-net-devices-${addresses.network.vpn.interface}.device"
      "sys-subsystem-net-devices-${addresses.network.lan.interface}.device"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
  };
}
