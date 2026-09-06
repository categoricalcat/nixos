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
          LinkLocalAddressing = "ipv6";
          IPv4Forwarding = true;
          IPv6Forwarding = true;
          IPv6AcceptRA = "no";
          DHCPPrefixDelegation = true;
          IPv6SendRA = true;
        };
        dhcpPrefixDelegationConfig = {
          UplinkInterface = addresses.network.wan.primary.interface;
          SubnetId = 1;
          Token = untrusted.ipv6.interfaceId;
          Announce = true;
          Assign = true;
          ManageTemporaryAddress = false;
        };
        ipv6SendRAConfig = {
          EmitDNS = true;
          DNS = "_link_local";
        };
        linkConfig.RequiredForOnline = "no";
      };
    };
  };
}
