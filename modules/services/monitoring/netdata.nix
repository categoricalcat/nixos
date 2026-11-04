{
  pkgs,
  lib,
  config,
  allAddresses,
  ...
}:

let
  inherit (config.yi.netdata) childMode;
  monitoringLib = import ./lib.nix;
  yirukouLan = allAddresses.hosts.yirukou.network.lan.ipv4.host;
  parentLan = (monitoringLib.getCentralHost allAddresses).network.lan.ipv4.host;
  netdataPort = 19999;
  streamTarget =
    if childMode then
      "destination = ${parentLan}:${toString netdataPort}"
    else
      "allow from = ${yirukouLan}";
  chronyDependencies = [
    "chronyd.service"
    "network-online.target"
  ];
  netdataDependencies = [
    "network-online.target"
    "chrony-waitsync-for-netdata.service"
  ];
in
{
  options.yi.netdata = {
    childMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        false (default): parent mode, accepts incoming streams from children.
        true: child mode, streams all metrics to parent at ${parentLan}.
      '';
    };
  };

  config = {
    services.netdata = {
      enable = true;
      package = pkgs.netdata.override { withCloudUi = true; };
      config = {
        global = {
          "memory mode" = "dbengine";
          "update every" = "1";
        };
        web = {
          "bind to" = if childMode then "127.0.0.1" else "0.0.0.0";
          "default port" = toString netdataPort;
          "allow connections from" =
            if childMode then "localhost 127.0.0.1" else "localhost 127.0.0.1 10.42.0.*";
        };
        "plugin:freeipmi" = {
          enabled = "no";
        };
        "plugin:python.d" = {
          enabled = "no";
        };
      };
    };

    services.netdata.configDir."stream.conf" = pkgs.writeText "stream.conf" ''
      [stream]
          enabled = yes
          ${streamTarget}
    '';

    systemd.services = {
      chrony-waitsync-for-netdata = monitoringLib.mkWantsAfter chronyDependencies // {
        description = "Wait for Chrony synchronization before Netdata";
        before = [ "netdata.service" ];
        script = ''
          ${config.services.chrony.package}/bin/chronyc waitsync 30 0.5 5 2 || true
        '';
        serviceConfig = {
          Type = "oneshot";
          TimeoutStartSec = "75s";
        };
      };

      netdata = monitoringLib.mkWantsAfter netdataDependencies // {
        preStart = "mkdir -p /tmp/netdata";
      };
    };
  };
}
