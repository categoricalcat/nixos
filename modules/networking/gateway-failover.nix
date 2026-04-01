{ addresses, pkgs, ... }:

let
  inherit (addresses.network.lan) interface;
  inherit (addresses.network.lan.ipv4) gateway;
  pingTargets = [
    "1.1.1.1"
    "8.8.8.8"
    "9.9.9.9"
  ];
  pingCount = 1;
  pingTimeout = 2;
  pingDeadline = 5;
  metric = 100;
  sleepInterval = 2;

  script = pkgs.writeShellApplication {
    name = "gateway-failover";
    runtimeInputs = with pkgs; [
      iproute2
      iputils
      gnugrep
      coreutils
      util-linux
    ];
    text = builtins.readFile ./gateway-failover.sh;
  };
in
{
  systemd.services."gateway-failover-${interface}" = {
    description = "Layer 3 WAN failover monitor for ${interface}";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment = {
      INTERFACE = interface;
      GATEWAY = gateway;
      CHECK_IPS = builtins.concatStringsSep " " pingTargets;
      PING_COUNT = toString pingCount;
      PING_TIMEOUT = toString pingTimeout;
      DEADLINE = toString pingDeadline;
      METRIC = toString metric;
      INTERVAL = toString sleepInterval;
    };
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "3s";
      StandardOutput = "journal";
      StandardError = "journal";
      StartLimitBurst = 5;
      ExecStart = "${script}/bin/gateway-failover";
    };
  };
}
