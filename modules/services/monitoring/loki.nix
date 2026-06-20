{
  allAddresses,
  config,
  ...
}:

let
  inherit (allAddresses) monitoring;
  centralHost = allAddresses.hosts.${monitoring.centralHost};
  loki = centralHost.services.loki;
  dataDir = config.services.loki.dataDir;
  retention = "168h";
in
{
  assertions = [
    {
      assertion = config.networking.hostName == monitoring.centralHost;
      message = "modules/services/monitoring/loki.nix: may only be imported on ${monitoring.centralHost}";
    }
  ];

  services.loki = {
    enable = true;

    configuration = {
      auth_enabled = false;

      analytics.reporting_enabled = false;

      server = {
        http_listen_address = centralHost.network.lan.ipv4.host;
        http_listen_port = loki.port;
        grpc_listen_address = "127.0.0.1";
        grpc_listen_port = 9096;
      };

      common = {
        path_prefix = dataDir;
        replication_factor = 1;
        ring = {
          instance_addr = centralHost.network.lan.ipv4.host;
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
