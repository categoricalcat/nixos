{ addresses, ... }:

let
  inherit (addresses.network.wan) primary fallback;
in
{
  systemd.network.networks = {
    "10-${primary.interface}" = {
      matchConfig.Name = primary.interface;
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = "yes";
      };
      dhcpV4Config = {
        RouteMetric = primary.routeMetric;
        UseDNS = true;
        UseRoutes = false;
      };
      linkConfig.RequiredForOnline = "routable";
    };

    "11-${fallback.interface}" = {
      matchConfig.Name = fallback.interface;
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = "yes";
      };
      dhcpV4Config = {
        RouteMetric = fallback.routeMetric;
        UseDNS = true;
      };
      linkConfig.RequiredForOnline = "no";
    };
  };
}
