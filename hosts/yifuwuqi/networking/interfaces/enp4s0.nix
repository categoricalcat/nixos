{ addresses, ... }:

{
  systemd.network = {
    networks = {
      # Fallback uplink. networkd owns its default route: UseGateway installs
      # the lease's router at a metric above the primary's and restores it
      # with every lease, so it is already in place whenever wan-monitor
      # withdraws the primary default (see
      # packages/gateway-failover/default.nix).
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
          UseDNS = false;
          UseRoutes = false;
          UseGateway = true;
          RouteMetric = addresses.network.secondary.routeMetric;
        };

        linkConfig = {
          MTUBytes = 1500;
          RequiredForOnline = "no";
        };
      };
    };
  };
}
