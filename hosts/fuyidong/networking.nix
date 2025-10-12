_: {
  networking = {
    hostName = "fuyidong";

    enableIPv6 = true;
    tempAddresses = "disabled";

    networkmanager = {
      enable = true;
    };

    firewall = {
      allowedUDPPorts = [ 51820 ];
    };

    wireguard = {
      interfaces = {
        wg0 = {
          listenPort = 51820;
          ips = [ "10.100.0.2/32" ];

          privateKeyFile = "/etc/wireguard/private.key";

          peers = [
            {
              name = "fufuwuqi.vpn";
              publicKey = "QA2qAna4n/CvD3xKXEgMaiwDWZpH3lC2Kn76oJ6rcRw=";

              allowedIPs = [ "0.0.0.0/0" ];

              endpoint = "fufuwuqi.lan:51820";

              persistentKeepalive = 25;
            }
          ];
        };
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
