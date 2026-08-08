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
        address = [ untrusted.ipv4.address ];
        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = "no";
          LinkLocalAddressing = "no";
          IPv4Forwarding = true;
        };
        linkConfig.RequiredForOnline = "no";
      };
    };
  };
}
