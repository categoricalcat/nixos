{ addresses, ... }:
{

  services.openvscode-server = {
    enable = true;
    inherit (addresses.network.vpn.ipv4) host;
    port = 4444;
    user = "fufud";
    group = "fufud";
    telemetryLevel = "off";
    withoutConnectionToken = true;
  };

  systemd.services."openvscode-server" = {
    wants = [
      "network-online.target"
    ];
    after = [
      "network-online.target"
    ];
  };
}
