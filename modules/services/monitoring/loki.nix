{
  allAddresses,
  config,
  ...
}:

let
  inherit (allAddresses) monitoring;
  monitoringLib = import ./lib.nix;
  centralHost = monitoringLib.getCentralHost allAddresses;
  lokiAddress = centralHost.network.lan.ipv4.host;
  loki = centralHost.services.loki;
  dataDir = monitoring.dataDirs.loki;
  retention = "168h";
in
{
  assertions = [
    (monitoringLib.mkCentralHostAssertion {
      modulePath = "modules/services/monitoring/loki.nix";
      inherit monitoring;
      hostName = config.networking.hostName;
    })
  ];

  services.loki = {
    enable = true;
    inherit dataDir;

    configuration = {
      auth_enabled = false;

      analytics.reporting_enabled = false;

      server = {
        http_listen_address = lokiAddress;
        http_listen_port = loki.port;
        grpc_listen_address = "0.0.0.0";
        grpc_listen_port = 9096;
      };

      common = {
        path_prefix = dataDir;
        replication_factor = 1;
        ring = {
          instance_addr = lokiAddress;
          kvstore.store = "inmemory";
        };
      };

      schema_config.configs = [
        {
          from = "2024-01-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];

      storage_config.filesystem.directory = "${dataDir}/chunks";

      compactor = {
        working_directory = "${dataDir}/compactor";
        compaction_interval = "10m";
        retention_enabled = true;
        retention_delete_delay = "2h";
        delete_request_store = "filesystem";
      };

      limits_config = {
        retention_period = retention;
        allow_structured_metadata = true;
      };
    };
  };
}
