{ systemNameservers, ... }:

{
  systemd.network = {
    netdevs = {
      "10-bond0" = {
        netdevConfig = {
          Kind = "bond";
          Name = "bond0";
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
          Bond = "bond0";
          PrimarySlave = true;
          DNS = systemNameservers;
        };
        linkConfig = {
          MTUBytes = 1492;
        };
      };

      "30-enp4s0" = {
        matchConfig.Name = "enp4s0";
        networkConfig = {
          Bond = "bond0";
          DNS = systemNameservers;
        };
        linkConfig = {
          MTUBytes = 1492;
        };
      };

      "40-bond0" = {
        matchConfig.Name = "bond0";
        networkConfig = {
          DHCP = "no";
          DNS = systemNameservers;
          MulticastDNS = "yes";
          IPv6AcceptRA = "no";
          LinkLocalAddressing = "ipv6";

          Address = [
            "2804:41fc:8030:ace0::40/64"
            "192.168.1.40/24"
          ];
        };

        linkConfig = {
          MTUBytes = 1492;
          RequiredForOnline = "carrier";
        };

        routes = [
          {
            Gateway = "fe80::1";
            GatewayOnLink = true;
            Metric = 5;
          }
          {
            Gateway = "192.168.1.1";
            GatewayOnLink = true;
            Metric = 1000;
          }
        ];

      };
    };
  };
}
