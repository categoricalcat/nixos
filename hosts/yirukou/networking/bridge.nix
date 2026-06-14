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
          lan.ipv4.address
          "${addresses.network.sinkhole.ipv4.host}/${toString lan.ipv4.prefixLength}"
        ];
        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = "no";
          LinkLocalAddressing = "no";
          IPv4Forwarding = true;
        };
        linkConfig.RequiredForOnline = "routable";
      };
    }
    // builtins.listToAttrs (lib.imap0 mkBridgePort bridgePorts);
  };
}
