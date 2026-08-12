{
  pkgs,
  lib,
  config,
  allAddresses,
  ...
}:

let
  inherit (config.yi.netdata) childMode;
  yirukouLan = allAddresses.hosts.yirukou.network.lan.ipv4.host;
  yifuwuqiLan = allAddresses.hosts.yifuwuqi.network.lan.ipv4.host;
in
{
  options.yi.netdata = {
    childMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        false (default): parent mode, accepts incoming streams from children.
        true: child mode, streams all metrics to parent at ${yifuwuqiLan}.
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
          "default port" = "19999";
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

    services.netdata.configDir."stream.conf" = pkgs.writeText "stream.conf" (
      if childMode then
        ''
          [stream]
              enabled = yes
              destination = ${yifuwuqiLan}:19999
        ''
      else
        ''
          [stream]
              enabled = yes
              allow from = ${yirukouLan}
        ''
    );

    systemd.services = {
      chrony-waitsync-for-netdata = {
        description = "Wait for Chrony synchronization before Netdata";
        wants = [
          "chronyd.service"
          "network-online.target"
        ];
        after = [
          "chronyd.service"
          "network-online.target"
        ];
        before = [ "netdata.service" ];
        script = ''
          ${config.services.chrony.package}/bin/chronyc waitsync 30 0.5 5 2 || true
        '';
        serviceConfig = {
          Type = "oneshot";
          TimeoutStartSec = "75s";
        };
      };

      netdata = {
        wants = [
          "network-online.target"
          "chrony-waitsync-for-netdata.service"
        ];
        after = [
          "network-online.target"
          "chrony-waitsync-for-netdata.service"
        ];
        preStart = "mkdir -p /tmp/netdata";
      };
    };
  };
}
