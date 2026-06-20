{
  allAddresses,
  config,
  lib,
  ...
}:

let
  inherit (allAddresses) hosts monitoring;
  centralHost = hosts.${monitoring.centralHost};
  prometheus = centralHost.services.prometheus;
  exporterMetadata = monitoring.exporters;

  resolveHosts =
    selector:
    if builtins.isList selector then
      selector
    else if selector == "centralHost" then
      [ monitoring.centralHost ]
    else if selector == "proxyHost" then
      [ monitoring.proxyHost ]
    else
      monitoring.${selector};

  hostAddress =
    name: if name == monitoring.centralHost then "127.0.0.1" else hosts.${name}.network.lan.ipv4.host;

  mkStaticConfig = exporter: host: {
    targets = [
      "${hostAddress host}:${toString config.services.prometheus.exporters.${exporter}.port}"
    ];
    labels = { inherit host; };
  };

  mkScrapeConfig =
    exporter: spec:
    {
      job_name = exporter;
      static_configs = map (mkStaticConfig exporter) (resolveHosts spec.hosts);
    }
    // lib.optionalAttrs (spec ? scrapeInterval) {
      scrape_interval = spec.scrapeInterval;
    };
in
{
  assertions = [
    {
      assertion = config.networking.hostName == monitoring.centralHost;
      message = "modules/services/monitoring/prometheus.nix: may only be imported on ${monitoring.centralHost}";
    }
  ];

  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    inherit (prometheus) port;
    retentionTime = "30d";
    enableReload = true;
    checkConfig = true;

    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };

    scrapeConfigs = [
      {
        job_name = "prometheus";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString prometheus.port}" ];
            labels.host = monitoring.centralHost;
          }
        ];
      }
    ]
    ++ lib.mapAttrsToList mkScrapeConfig exporterMetadata;
  };
}
