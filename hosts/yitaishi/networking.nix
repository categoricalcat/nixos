{ lib, ... }:
let
  wgCommon = {
    listenPort = 51820;
    address = [ "10.100.0.3/32" ];
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
    lan = "192.168.0.42:51820";
    remote = "wg.localto.net:51820";
  };
in
{
  networking = {
    hostName = "yitaishi";

    networkmanager = {
      enable = true;
    };

    firewall = {
      allowedUDPPorts = [ 51820 ];
      checkReversePath = "loose";
    };

    # wg-quick.interfaces = {
    #   "yifuwuqi.vpn" = wgCommon // {
    #     peers = [
    #       (mkPeer {
    #         endpoint = endpoints.remote;
    #       })
    #     ];
    #   };
    # };
  };

  systemd.services.NetworkManager-wait-online.enable = false;

  # systemd.services."wg-quick-yifuwuqi.vpn" = {
  #   serviceConfig = {
  #     Type = lib.mkForce "simple";
  #     Restart = "on-failure";
  #     RestartSec = "5s";
  #   };
  # };

}
