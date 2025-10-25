{ pkgs, ... }:

{
  services.cockpit = {
    enable = true;
    port = 9090;
    allowed-origins = [
      "http://localhost:9090"
      "https://localhost:9090"
      "http://fufuwuqi.local:9090"
      "https://fufuwuqi.local:9090"
      "http://fufuwuqi.vpn:9090"
      "https://fufuwuqi.vpn:9090"
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
