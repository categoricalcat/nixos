{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:

let
  unstable = import ../../nixpkgs-unstable.nix { inherit inputs pkgs; };
  inherit (config.yi.netdata) childMode;
in
{
  options.yi.netdata = {
    childMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        false (default): parent mode, accepts incoming streams from children.
        true: child mode, streams all metrics to parent at 10.42.0.1.
      '';
    };
  };

  config = {
    services.netdata = {
      enable = true;
      package = unstable.netdata.override { withCloudUi = true; };
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

    environment.etc."netdata/stream.conf" = lib.mkMerge [
      (lib.mkIf childMode {
        text = ''
          [stream]
              enabled = yes
              destination = 10.42.0.1:19999
        '';
      })
      (lib.mkIf (!childMode) {
        text = ''
          [stream]
              enabled = yes
              allow from = 10.42.0.2
        '';
      })
    ];

    systemd.services.netdata = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      preStart = "mkdir -p /tmp/netdata";
    };
  };
}
