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

  hostRelabelConfig = [
    {
      source_labels = [ "host" ];
      target_label = "instance";
    }
  ];

  mkScrapeConfig =
    exporter: spec:
    {
      job_name = exporter;
      static_configs = map (mkStaticConfig exporter) (resolveHosts spec.hosts);
      relabel_configs = hostRelabelConfig;
    }
    // lib.optionalAttrs (spec ? scrapeInterval) {
      scrape_interval = spec.scrapeInterval;
    }
    // lib.optionalAttrs (spec ? metricRelabelConfigs) {
      metric_relabel_configs = spec.metricRelabelConfigs;
    };

  # One blackbox probe job for every (scrape host x layer x target). The
  # blackbox module name equals the layer / `monitoring.probes` key.
  probeScrapeConfig = {
    job_name = "probe";
    metrics_path = "/probe";
    static_configs = lib.concatMap (
      host:
      lib.mapAttrsToList (layer: targets: {
        inherit targets;
        labels = {
          inherit host layer;
          __param_module = layer;
          __tmp_address = "${hostAddress host}:${toString config.services.prometheus.exporters.blackbox.port}";
        };
      }) monitoring.probes
    ) monitoring.scrapeHosts;
    relabel_configs = [
      {
        source_labels = [ "__address__" ];
        target_label = "__param_target";
      }
      {
        source_labels = [ "__param_target" ];
        target_label = "instance";
      }
      {
        source_labels = [ "__tmp_address" ];
        target_label = "__address__";
      }
    ];
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
        relabel_configs = hostRelabelConfig;
      }
      {
        job_name = "loki";
        static_configs = [
          {
            targets = [ "${centralHost.network.lan.ipv4.host}:${toString centralHost.services.loki.port}" ];
            labels.host = monitoring.centralHost;
          }
        ];
        relabel_configs = hostRelabelConfig;
      }
      {
        job_name = "grafana";
        static_configs = [
          {
            targets = [ "${centralHost.network.lan.ipv4.host}:${toString centralHost.services.grafana.port}" ];
            labels.host = monitoring.centralHost;
          }
        ];
        relabel_configs = hostRelabelConfig;
      }
      probeScrapeConfig
    ]
    ++ lib.mapAttrsToList mkScrapeConfig exporterMetadata;
  };
}
