{ addresses, ... }:

{
  systemd.network = {
    netdevs = {
      "10-bond0" = {
        netdevConfig = {
          Kind = "bond";
          Name = addresses.network.lan.interface;
          MTUBytes = 1492;
        };
        bondConfig = {
          Mode = "active-backup";
          MIIMonitorSec = "0.05";
          PrimaryReselectPolicy = "better";
          UpDelaySec = 0;
          DownDelaySec = 0;
        };
      };
    };

    networks = {
      "30-eno1" = {
        matchConfig.Name = "eno1";
        networkConfig = {
          Bond = addresses.network.lan.interface;
          PrimarySlave = true;
        };
        linkConfig = {
          MTUBytes = 1492;
        };
      };

      "30-enp4s0" = {
        matchConfig.Name = "enp4s0";
        networkConfig = {
          Bond = addresses.network.lan.interface;
        };
        linkConfig = {
          MTUBytes = 1492;
        };
      };

      "40-bond0" = {
        matchConfig.Name = addresses.network.lan.interface;
        networkConfig = {
          DHCP = "no";
          DNS = addresses.dns.upstreamDnsServers;
          MulticastDNS = "yes";
          IPv6AcceptRA = "yes";
          LinkLocalAddressing = "ipv6";

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
            Metric = 1000;
          }
        ];

        ipv6AcceptRAConfig = {
          RouteMetric = 5;
        };
      };
    };
  };
}
