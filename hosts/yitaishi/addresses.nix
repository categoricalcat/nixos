_: {
  _module.args.addresses = rec {
    ssh = {
      listenPort = 22;
      listenAddresses = [
        #"10.100.0.3"
      ];
      listenWildcardIPv6 = null;
    };
  };
}
