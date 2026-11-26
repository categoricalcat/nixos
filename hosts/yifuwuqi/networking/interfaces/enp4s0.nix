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
          MulticastDNS = "yes";
          IPv6AcceptRA = "no";
          LinkLocalAddressing = "no";
        };

        dhcpV4Config = {
          # eno1 is the resolver: the fallback uplink must not add its router's
          # DNS as a second path.
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
