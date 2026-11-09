{
  allAddresses,
  config,
  lib,
  systemdHardening,
  ...
}:

let
  monitoringLib = import ./lib.nix;
  hostName = config.networking.hostName;
  centralHost = monitoringLib.getCentralHost allAddresses;
  loki = centralHost.services.loki;
in
{
  services.vector = {
    enable = true;
    journaldAccess = true;

    settings = {
      sources.journald.type = "journald";

      transforms.enrich_journal = {
        type = "remap";
        inputs = [ "journald" ];
        source = ''
          unit = string(._SYSTEMD_UNIT) ?? ""
          if unit == "" {
            unit = string(.SYSLOG_IDENTIFIER) ?? ""
          }
          if unit == "" {
            unit = "system"
          }
          .unit = unit
        '';
      };

      sinks.loki = {
        type = "loki";
        inputs = [ "enrich_journal" ];
        endpoint = monitoringLib.lanHttpEndpoint centralHost loki;
        labels = {
          host = hostName;
          job = "systemd-journal";
          unit = "{{ unit }}";
        };
        encoding.codec = "text";
      };
    };
  };

  systemd.services.vector.serviceConfig = systemdHardening // {
    # Vector here only reads the journal and pushes to Loki; the nixpkgs
    # default grant is for configs that bind privileged ports.
    AmbientCapabilities = lib.mkForce "";
  };
}
