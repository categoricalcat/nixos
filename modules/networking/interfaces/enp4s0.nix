{ addresses, ... }:

{
  systemd.network = {
    networks = {
      # Fallback uplink. The DHCP-assigned default route gets metric 1000 so
      # the kernel only uses it when the primary (eno1, metric 100) is gone.
      "35-enp4s0" = {
        matchConfig.Name = addresses.network.secondary.interface;
        networkConfig = {
          DHCP = "ipv4";
          DNS = addresses.dns.systemNameservers;
          MulticastDNS = "yes";
          IPv6AcceptRA = "no";
          LinkLocalAddressing = "no";
        };

        dhcpV4Config = {
          RouteMetric = 1500;
          UseDNS = false;
        };

        linkConfig = {
          MTUBytes = 1500;
          RequiredForOnline = "no";
        };
      };
    };
  };
}
