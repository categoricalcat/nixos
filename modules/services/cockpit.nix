{ pkgs, addresses, ... }:

let
  cockpit = addresses.services.cockpit;
  port = toString cockpit.port;
in
{
  services.cockpit = {
    enable = true;
    inherit (cockpit) port;
    allowed-origins = [
      "http://localhost:${port}"
      "https://localhost:${port}"
      "http://${addresses.hostName}.local:${port}"
      "https://${addresses.hostName}.local:${port}"
      "http://${addresses.network.vpn.ipv4.host}:${port}"
      "https://${addresses.network.vpn.ipv4.host}:${port}"
      "https://${cockpit.domain}"
    ];
    settings = {
      WebService = {
        AllowUnencrypted = true;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    sysstat
  ];

  systemd.services.cockpit = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };
}
