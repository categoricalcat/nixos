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

        linkConfig = {
          MTUBytes = 1492;
          RequiredForOnline = "carrier";
        };
      };
    };
  };
}
