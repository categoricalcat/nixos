{ addresses, ... }:

{
  systemd.network = {
    networks = {
      "30-eno1" = {
        matchConfig.Name = addresses.network.lan.interface;
        networkConfig = {
          DHCP = "no";
          DNS = addresses.dns.lanUpstreams;
          Domains = [ "~." ];
          MulticastDNS = "yes";
          IPv6AcceptRA = "no";
          LinkLocalAddressing = "ipv6";
        };

        address = [
          addresses.network.lan.ipv6.address
          addresses.network.lan.ipv4.address
        ];

        # The metric-100 default route is owned exclusively by wan-monitor
        # (see ../../../../packages/gateway-failover/default.nix), which
        # withdraws it while the uplink is unhealthy, so networkd must not
        # install it. wan-monitor also pins a /32 host route to each probe
        # target via the LAN gateway, so those appearing on eno1 is expected.

        linkConfig = {
          MTUBytes = 1492;
          RequiredForOnline = "carrier";
        };
      };
    };
  };
}
