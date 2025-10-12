_: {
  _module.args.addresses = {
    hostName = "fufuwuqi";

    dns = {
      systemNameservers = [
        "::1"
        "127.0.0.1"
      ];
      quad9 = [
        "dns.quad9.net"
        "https://dns.quad9.net/dns-query"
        "2620:fe::fe"
        "2620:fe::9"
        "9.9.9.9"
        "149.112.112.112"

      ];
      google = [
        "dns.google.com"
        "https://dns.google/dns-query"
        "2001:4860:4860::8888"
        "2001:4860:4860::8844"
        "8.8.8.8"
        "8.8.4.4"
      ];
      cloudflare = [
        "1dot1dot1dot1.cloudflare-dns.com"
        "https://cloudflare-dns.com/dns-query"
        "2606:4700:4700::1111"
        "2606:4700:4700::1001"
        "1.1.1.1"
        "1.0.0.1"
      ];
      adguard = [
        "dns.adguard-dns.com"
        "https://dns.adguard-dns.com/dns-query"
        "94.140.14.14"

      ];
      domain = "vpn";
    };

    network = {
      vpn = {
        interface = "wg0";
        # ipv6 = rec {
        #   host = "2804:41fc:8030:ace1::1";
        #   prefixLength = 64;
        #   address = "${host}/${builtins.toString prefixLength}";
        # };
        ipv4 = rec {
          host = "10.100.0.1";
          prefixLength = 24;
          address = "${host}/${builtins.toString prefixLength}";
        };
        peers = [
          {
            publicKey = "lGriY6UJK7M4O9oOq/JBHM6/HXTUx5pX/VH97Cs2njo=";
            allowedIPs = [
              "10.100.0.2/32" # fuyidong
            ];
            keepalive = 25;
          }
          {
            publicKey = "aDcV7ZGtQTg/0twxpObeU1FM+nBFgD9wlYQ8Txygf3U=";
            allowedIPs = [
              "10.100.0.3/32" # fuchuang
            ];
            keepalive = 25;
          }
          {
            publicKey = "azePQG6Sbg9O2jNDVMU99jPO96yfNGjd+FM0FdsI0Q8=";
            allowedIPs = [
              "10.100.0.4/32" # *her*
            ];
            keepalive = 25;
          }
        ];
      };

      lan = {
        interface = "bond0";
        # ipv6 = rec {
        #   host = "2804:41fc:8030:ace0::40";
        #   prefixLength = 64;
        #   address = "${host}/${builtins.toString prefixLength}";
        #   gateway = "fe80::1";
        # };
        ipv4 = rec {
          host = "192.168.1.42";
          prefixLength = 24;
          address = "${host}/${builtins.toString prefixLength}";
          gateway = "192.168.1.1";
        };
      };
    };

    wireguard = {
      listenPort = 51820;
    };

    ssh = {
      listenPort = 24212;
      listenAddresses = [
        "192.168.1.42"
        "10.100.0.1"
      ];
      listenWildcardIPv6 = "[::]";
    };

    containers = {
      subnetPools = [
        {
          base = "172.17.0.0/16";
          size = 24;
        }
        {
          base = "172.18.0.0/16";
          size = 24;
        }
      ];
    };
  };
}
