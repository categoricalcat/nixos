{
  addresses,
  lib,
  ...
}:

let
  inherit (addresses.network) lan untrusted;
  bridgePorts = lib.filter (port: port != untrusted.parentInterface) lan.ports;
  mkBridgePort = index: port: {
    name = "${toString (31 + index)}-${port}";
    value = {
      matchConfig.Name = port;
      networkConfig = {
        Bridge = lan.interface;
        LinkLocalAddressing = "no";
      };
      linkConfig.RequiredForOnline = "no";
    };
  };
in
{
  systemd.network = {
    netdevs."10-${lan.interface}" = {
      netdevConfig = {
        Kind = "bridge";
        Name = lan.interface;
      };
    };

    networks = {
      "20-${lan.interface}" = {
        matchConfig.Name = lan.interface;
        address = [
          lan.ipv6.address
          lan.ipv4.address
          "${addresses.network.sinkhole.ipv4.host}/${toString lan.ipv4.prefixLength}"
          "${addresses.network.sinkhole.ipv6.host}/128"
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
          DNS = lan.ipv6.host;
        };
        ipv6Prefixes = [ { Prefix = lan.ipv6.cidr; } ];
        linkConfig.RequiredForOnline = "routable";
      };
    }
    // builtins.listToAttrs (lib.imap0 mkBridgePort bridgePorts);
  };
}
