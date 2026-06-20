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

      sinks.loki = {
        type = "loki";
        inputs = [ "journald" ];
        endpoint = "http://${centralHost.network.lan.ipv4.host}:${toString loki.port}";
        labels = {
          host = hostName;
          job = "systemd-journal";
        };
        encoding.codec = "text";
      };
    };
  };
}
