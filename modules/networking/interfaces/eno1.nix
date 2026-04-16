{ addresses, ... }:

{
  systemd.network = {
    networks = {
      "30-eno1" = {
        matchConfig.Name = addresses.network.lan.interface;
        networkConfig = {
          DHCP = "no";
          DNS = addresses.dns.systemNameservers;
          MulticastDNS = "yes";
          IPv6AcceptRA = "no";
          LinkLocalAddressing = "no";

          Address = [
            # addresses.network.lan.ipv6.address
            addresses.network.lan.ipv4.address
            "${addresses.network.sinkhole.ipv4.host}/24"
          ];
        };

        linkConfig = {
          MTUBytes = 1492;
          RequiredForOnline = "carrier";
        };
        # The health-checked default route is owned by gateway-failover so it
        # can be withdrawn cleanly when upstream connectivity fails.
      };
    };
  };
}
