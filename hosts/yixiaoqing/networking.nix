_: {
  networking = {
    hostName = "yixiaoqing";

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
        };
      };
    };

    firewall = {
      #allowedUDPPorts = [ 51820 ];
      checkReversePath = "loose";
    };

    #wg-quick.interfaces = {
    #  "yifuwuqi.vpn" = wgCommon // {
    #    peers = [
    #      (mkPeer {
    #        endpoint = endpoints.remote;
    #      })
    #    ];
    #  };
    #};
  };

  systemd.services.NetworkManager-wait-online.enable = false;

  #systemd.services."wg-quick-yifuwuqi.vpn" = {
  #  serviceConfig = {
  #    Type = lib.mkForce "simple";
  #    Restart = "on-failure";
  #    RestartSec = "5s";
  #  };
  #};

}
