_: {
  _module.args.addresses = {
    hostName = "fufuwuqi";

    dns = {
      systemNameservers = [
        "2804:41fc:8030:ace1::1"
        "10.100.0.1"
      ];
      upstreamDnsServers = [
        "2001:4860:4860::8888"
        "2606:4700:4700::1111"
        "8.8.8.8"
        "1.1.1.1"
      ];
      domain = "vpn";
    };

    network = {
      vpn = {
        interface = "wg0";
        ipv6 = rec {
          host = "2804:41fc:8030:ace1::1";
          prefixLength = 64;
          address = "${host}/${builtins.toString prefixLength}";
        };
        ipv4 = rec {
          host = "10.100.0.1";
          prefixLength = 24;
          address = "${host}/${builtins.toString prefixLength}";
        };
        peers = [
          {
            publicKey = "e234011QJdJtl67vFF8Dp3wGLixnkRFXtkcDamR1vh8=";
            allowedIPs = [
              "2804:41fc:8030:ace1::2/128"
              "10.100.0.2/32"
            ];
            keepalive = 25;
          }
          {
            publicKey = "aDcV7ZGtQTg/0twxpObeU1FM+nBFgD9wlYQ8Txygf3U=";
            allowedIPs = [
              "2804:41fc:8030:ace1::3/128"
              "10.100.0.3/32"
            ];
            keepalive = 25;
          }
        ];
      };

      lan = {
        interface = "bond0";
        ipv6 = rec {
          host = "2804:41fc:8030:ace0::40";
          prefixLength = 64;
          address = "${host}/${builtins.toString prefixLength}";
          gateway = "fe80::1";
        };
        ipv4 = rec {
          host = "192.168.1.40";
          prefixLength = 24;
          address = "${host}/${builtins.toString prefixLength}";
          gateway = "192.168.1.1";
        };
      };

      usb = rec {
        host = "192.168.100.1";
        prefixLength = 24;
        address = "${host}/${builtins.toString prefixLength}";
      };
    };

    wireguard = {
      listenPort = 51820;
    };

    ssh = {
      listenPort = 24212;
      listenAddresses = [
        "192.168.1.40"
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
