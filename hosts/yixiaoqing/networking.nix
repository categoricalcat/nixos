_: {
  networking = {
    hostName = "yixiaoqing";

    networkmanager = {
      enable = true;
      wifi = {
        powersave = true;
        # backend = "iwd";
      };
    };

    wireless.iwd = {
      enable = false;
      settings = {
        General = {
          EnableNetworkConfiguration = false;
        };
      };
    };

    firewall = {
      #allowedUDPPorts = [ 51820 ];
      checkReversePath = "loose";
    };

    #wg-quick.interfaces = {
    #  "yifuwuqi.${addresses.network.vpn.domain}" = wgCommon // {
    #    peers = [
    #      (mkPeer {
    #        endpoint = endpoints.remote;
    #      })
    #    ];
    #  };
    #};
  };

  systemd.services.NetworkManager-wait-online.enable = false;

  #systemd.services."wg-quick-yifuwuqi.${addresses.network.vpn.domain}" = {
  #  serviceConfig = {
  #    Type = lib.mkForce "simple";
  #    Restart = "on-failure";
  #    RestartSec = "5s";
  #  };
  #};

}
