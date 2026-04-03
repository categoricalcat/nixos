{ addresses, ... }:

{
  systemd.network = {
    networks = {
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
          RouteMetric = 1000;
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
