_:

{
  systemd.network = {
    netdevs = {
      "30-wg0" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "wg0";
          MTUBytes = 1492;
        };
        wireguardConfig = {
          PrivateKeyFile = "/etc/wireguard/private.key";
          ListenPort = 51820;
        };
        wireguardPeers = [
          {
            PublicKey = "e234011QJdJtl67vFF8Dp3wGLixnkRFXtkcDamR1vh8=";
            AllowedIPs = [
              "fd00:100::2/128"
              "10.100.0.2/32"
            ];
            PersistentKeepalive = 25;
          }
          {
            PublicKey = "aDcV7ZGtQTg/0twxpObeU1FM+nBFgD9wlYQ8Txygf3U=";
            AllowedIPs = [
              "fd00:100::3/128"
              "10.100.0.3/32"
            ];
            PersistentKeepalive = 25;
          }
        ];
      };
    };

    networks = {
      "60-wg0" = {
        matchConfig.Name = "wg0";
        address = [
          "fd00:100::1/64"
          "10.100.0.1/24"
        ];
        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = "no";
          DNS = [
            "fd00:100::1"
            "10.100.0.1"
          ];
          Domains = [ "~vpn" ];
          DNSDefaultRoute = false;
          MulticastDNS = "yes";
        };
        linkConfig = {
          MTUBytes = 1492;
        };
      };
    };
  };
}
