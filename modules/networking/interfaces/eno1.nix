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
          ];
        };

        linkConfig = {
          MTUBytes = 1492;
          RequiredForOnline = "carrier";
        };

        routes = [
          # {
          #   Gateway = addresses.network.lan.ipv6.gateway;
          #   GatewayOnLink = true;
          #   Metric = 5;
          # }
          {
            Gateway = addresses.network.lan.ipv4.gateway;
            GatewayOnLink = true;
            Metric = 100;
          }
        ];
      };
    };
  };
}
