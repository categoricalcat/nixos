{ addresses, ... }:

let
  inherit (addresses.network) untrusted;
in
{
  systemd.network = {
    netdevs."20-${untrusted.interface}" = {
      netdevConfig = {
        Kind = "vlan";
        Name = untrusted.interface;
      };
      vlanConfig.Id = untrusted.vlanId;
    };

    networks = {
      "30-${untrusted.parentInterface}" = {
        matchConfig.Name = untrusted.parentInterface;
        vlan = [ untrusted.interface ];
        networkConfig = {
          LinkLocalAddressing = "no";
        };
        linkConfig.RequiredForOnline = "no";
      };

      "40-${untrusted.interface}" = {
        matchConfig.Name = untrusted.interface;
        address = [
          untrusted.ipv6.address
          untrusted.ipv4.address
        ];
        networkConfig = {
          LinkLocalAddressing = "ipv6";
          IPv4Forwarding = true;
          IPv6Forwarding = true;
          IPv6AcceptRA = "no";
          IPv6SendRA = true;
        };
        ipv6SendRAConfig = {
          RouterLifetimeSec = 0;
          EmitDNS = true;
          DNS = untrusted.ipv6.host;
        };
        ipv6Prefixes = [ { Prefix = untrusted.ipv6.cidr; } ];
        linkConfig.RequiredForOnline = "no";
      };
    };
  };
}
