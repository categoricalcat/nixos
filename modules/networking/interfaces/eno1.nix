{ addresses, ... }:

{
  systemd.network = {
    # keepalived owns the metric-100 default route (see gateway-failover.nix).
    # ManageForeignRoutes=no stops networkd from sweeping that route on reload
    # because it is not declared in any .network file.
    # ManageForeignRoutes lives in networkd.conf(5) [Network] (global),
    # not in per-link .network files.
    config.networkConfig.ManageForeignRoutes = false;

    networks = {
      "30-eno1" = {
        matchConfig.Name = addresses.network.lan.interface;
        networkConfig = {
          DHCP = "no";
          DNS = addresses.dns.systemNameservers;
          MulticastDNS = "yes";
          IPv6AcceptRA = "no";
          LinkLocalAddressing = "no";
        };

        address = [
          # addresses.network.lan.ipv6.address
          addresses.network.lan.ipv4.address
          "${addresses.network.sinkhole.ipv4.host}/24"
        ];

        # The metric-100 default route is owned exclusively by keepalived
        # (see modules/networking/gateway-failover.nix). networkd must not
        # install it - that would race with keepalived's notify script.
        #
        # gateway-failover.nix also merges a /32 tracker route here for the
        # WAN-check probe target (via the LAN gateway) so the keepalived
        # check has a guaranteed path out eno1 regardless of the default
        # route state. That's why `ip route` shows a host route on eno1.

        linkConfig = {
          MTUBytes = 1492;
          RequiredForOnline = "carrier";
        };
      };
    };
  };
}
