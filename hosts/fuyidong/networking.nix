_:
let
  wgCommon = {
    listenPort = 51820;
    address = [ "10.100.0.2/32" ];
    mtu = 1380;
    privateKeyFile = "/etc/wireguard/private.key";
    dns = [ "10.100.0.1" ];
  };

  mkPeer =
    { endpoint }:
    {
      publicKey = "QA2qAna4n/CvD3xKXEgMaiwDWZpH3lC2Kn76oJ6rcRw=";
      allowedIPs = [ "0.0.0.0/0" ];
      inherit endpoint;
      persistentKeepalive = 25;
    };

  endpoints = {
    lan = "192.168.1.42:51820";
    remote = "75.ip.sa.ply.gg:51820";
  };
in
{
  networking = {
    hostName = "fuyidong";

    enableIPv6 = true;
    tempAddresses = "disabled";

    networkmanager = {
      enable = true;
      wifi = {
        powersave = true;
        backend = "iwd";
      };
    };

    wireless.iwd = {
      enable = true;
      settings = {
        General = {
          EnableNetworkConfiguration = false;
          Country = "BR";
        };
      };
    };

    firewall = {
      allowedUDPPorts = [ 51820 ];
      checkReversePath = "loose";
    };

    wg-quick.interfaces = {
      "fufuwuqi.vpn" = wgCommon // {
        peers = [
          (mkPeer {
            endpoint = endpoints.lan;
          })
          (mkPeer {
            endpoint = endpoints.remote;
          })
        ];
      };
    };
  };

  environment.etc."gai.conf".text = ''
    # Prefer IPv6 over IPv4 for address selection
    # See gai.conf(5) for details
    precedence ::1/128       50     # localhost (IPv6)
    precedence ::/0          40     # IPv6 global
    precedence ::ffff:0:0/96 30     # IPv4-mapped IPv6
    precedence 2002::/16     20     # 6to4
    precedence 2001::/32     5      # Teredo
    precedence fc00::/7      3      # ULA
    precedence ::/96         1      # IPv4-compatible IPv6
    precedence ::1/128       50     # localhost
  '';
}
