{
  allAddresses,
  config,
  ...
}:

let
  inherit (allAddresses) monitoring;
  hostName = config.networking.hostName;
  centralHost = allAddresses.hosts.${monitoring.centralHost};
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
        endpoint = "http://${centralHost.network.lan.ipv4.host}:${toString loki.port}";
        labels = {
          host = hostName;
          job = "systemd-journal";
          unit = "{{ unit }}";
        };
        encoding.codec = "text";
      };
    };
  };
}
