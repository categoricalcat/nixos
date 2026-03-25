_: {
  _module.args.addresses = rec {
    hostName = "yixiaoqing";

    network = {
      tailscale = {
        interface = "tailscale0";
        ipv4 = rec {
          host = "100.69.0.3";
          prefixLength = 32;
          address = "${host}/${builtins.toString prefixLength}";
        };
      };
    };

    ssh = {
      listenPort = 22;
      listenAddresses = [
        "127.0.0.1"
        network.tailscale.ipv4.host
      ];
      listenWildcardIPv6 = null;
    };
  };
}
