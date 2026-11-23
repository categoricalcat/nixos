{
  allAddresses,
  config,
  lib,
  systemdHardening,
  ...
}:

let
  inherit (allAddresses) monitoring;
  monitoringLib = import ./lib.nix;
  centralHost = monitoringLib.getCentralHost allAddresses;
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
        http_listen_address = "127.0.0.1";
        http_listen_port = loki.port;
        grpc_listen_address = "127.0.0.1";
        grpc_listen_port = 9096;
      };

      common = {
        path_prefix = dataDir;
        replication_factor = 1;
        ring = {
          # Ring and RPC stay on loopback; the LAN only sees the mTLS ingress.
          instance_addr = "127.0.0.1";
          kvstore.store = "inmemory";
        };
      };

      # Single-binary: dial the query-frontend directly. The frontend ring
      # autodetects the LAN address, but gRPC binds loopback only.
      frontend_worker.frontend_address = "127.0.0.1:9096";

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

  systemd.services.loki.serviceConfig = systemdHardening // {
    # The nixpkgs module sets ProtectSystem=full; strict wins here.
    ProtectSystem = lib.mkForce "strict";
    # Go's net.Interfaces (ring/memberlist address autodetect) needs netlink.
    RestrictAddressFamilies = lib.splitString " " "AF_UNIX AF_INET AF_INET6 AF_NETLINK";
    # Data lives outside the state directory.
    ReadWritePaths = [ dataDir ];
    # Loopback only: the ingress reaches Loki in the same netns, and the
    # central host scrapes it through the same vhost.
    IPAddressAllow = [ "localhost" ];
  };
}
