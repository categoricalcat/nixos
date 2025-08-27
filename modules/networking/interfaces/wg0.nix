{ addresses, ... }:
{
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
          # addresses.network.vpn.ipv6.address
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
