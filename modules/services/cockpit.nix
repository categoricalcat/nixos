{ pkgs, addresses, ... }:

{
  services.cockpit = {
    enable = true;
    port = 9090;
    allowed-origins = [
      "http://localhost:9090"
      "https://localhost:9090"
      "http://yifuwuqi.local:9090"
      "https://yifuwuqi.local:9090"
      "http://${addresses.network.tailscale.ipv4.host}:9090"
      "https://${addresses.network.tailscale.ipv4.host}:9090"
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
