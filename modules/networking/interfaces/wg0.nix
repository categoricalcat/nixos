{
  addresses,
  lib,
  ...
}:

let
  peers = {
    yixiaoqing = {
      publicKey = "lGriY6UJK7M4O9oOq/JBHM6/HXTUx5pX/VH97Cs2njo=";
      ip = "10.100.0.2";
      description = "yixiaoqing mobile device";
      allowedSubnets = [ "10.100.0.0/24" ];
    };

    fushouji = {
      publicKey = "KAMil5qZr8qBGLFpGXa+zvU/fAQBnDLveh6BIwpV1AM=";
      ip = "10.100.0.3";
      description = "fushouji";
      allowedSubnets = [ "10.100.0.0/24" ];
    };

    reserved = {
      publicKey = "t3grmFcOy3IaqAEKSJawBO2SnUPMeCTjeAg";
      ip = "10.100.0.4";
      description = "router";
      allowedSubnets = [ "10.100.0.0/24" ];
    };

    # Template for adding new peers:
    # peerName = {
    #   publicKey = "base64-encoded-public-key";
    #   ip = "10.100.0.X";  # Choose next available IP
    #   description = "Device/user description";
    #   allowedSubnets = [
    #     "10.100.X.0/24"  # Optional: peer-specific subnet
    #   ];
    # };
  };

  mkPeerConfig = _name: peer: {
    inherit (peer) publicKey;
    allowedIPs = [ "${peer.ip}/32" ] ++ peer.allowedSubnets;
    keepalive = 25;
  };

  peerConfigs = lib.mapAttrsToList mkPeerConfig peers;

in
{
  _module.args.wireguardPeers = {
    inherit peers peerConfigs;

    nextAvailableIP =
      let
        usedIPs = lib.mapAttrsToList (_: peer: lib.toInt (lib.last (lib.splitString "." peer.ip))) peers;
        maxIP = lib.foldl' lib.max 1 usedIPs;
      in
      "10.100.0.${toString (maxIP + 1)}";

    peerTable = lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: peer:
        "| ${name} | ${peer.ip} | ${peer.description} | `${lib.substring 0 16 peer.publicKey}...` |"
      ) peers
    );
  };

  systemd.network = {
    netdevs = {
      "30-wg0" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = addresses.network.vpn.interface;
          MTUBytes = 1380;
        };
        wireguardConfig = {
          PrivateKeyFile = "/etc/wireguard/private.key";
          ListenPort = addresses.wireguard.listenPort;
        };
        wireguardPeers = map (peer: {
          PublicKey = peer.publicKey;
          AllowedIPs = peer.allowedIPs;
          PersistentKeepalive = peer.keepalive;
        }) addresses.network.vpn.peers;
      };
    };

    networks = {
      "60-wg0" = {
        matchConfig.Name = addresses.network.vpn.interface;
        address = [
          addresses.network.vpn.ipv6.address
          addresses.network.vpn.ipv4.address
        ];
        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = "no";
          Domains = [ "~${addresses.dns.domain}" ];
          DNS = addresses.dns.systemNameservers;
          DNSDefaultRoute = false;
          MulticastDNS = "yes";
        };
        linkConfig = {
          MTUBytes = 1380;
        };
      };
    };
  };
}
