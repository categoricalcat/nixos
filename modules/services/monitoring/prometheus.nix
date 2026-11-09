{
  allAddresses,
  config,
  lib,
  ...
}:

let
  inherit (allAddresses) monitoring;
  monitoringLib = import ./lib.nix;
  centralHost = monitoringLib.getCentralHost allAddresses;
  prometheus = centralHost.services.prometheus;
  exporterMetadata = monitoring.exporters;

  mkStaticConfig = exporter: host: {
    targets = [
      "${monitoringLib.exporterAddress allAddresses host}:${
        toString config.services.prometheus.exporters.${exporter}.port
      }"
    ];
    labels = { inherit host; };
  };

  mkScrapeConfig =
    exporter: spec:
    {
      job_name = exporter;
      static_configs = map (mkStaticConfig exporter) (monitoringLib.resolveHosts monitoring spec.hosts);
      relabel_configs = monitoringLib.hostRelabelConfig;
    }
    // lib.optionalAttrs (spec ? scrapeInterval) {
      scrape_interval = spec.scrapeInterval;
    }
    // lib.optionalAttrs (spec ? metricRelabelConfigs) {
      metric_relabel_configs = spec.metricRelabelConfigs;
    };

  mkCentralScrapeJob = jobName: target: {
    job_name = jobName;
    static_configs = [
      {
        targets = [ target ];
        labels.host = monitoring.centralHost;
      }
    ];
    relabel_configs = monitoringLib.hostRelabelConfig;
  };

  # One blackbox probe job for every (scrape host x probe), minus the host's
  # own peer entry: pinging itself measures nothing the adguard and unbound
  # exporters do not already cover. The blackbox module name equals the
  # probe's layer.
  probeScrapeConfig = {
    job_name = "probe";
    metrics_path = "/probe";
    static_configs = lib.concatMap (
      host:
      map (probe: {
        targets = [ probe.target ];
        labels = {
          inherit host;
          inherit (probe)
            layer
            family
            peer
            scope
            tier
            ;
          __param_module = probe.layer;
          __tmp_address = "${monitoringLib.exporterAddress allAddresses host}:${toString config.services.prometheus.exporters.blackbox.port}";
        };
      }) (lib.filter (probe: probe.peer != host) monitoring.probes)
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
    (monitoringLib.mkCentralHostAssertion {
      modulePath = "modules/services/monitoring/prometheus.nix";
      inherit monitoring;
      hostName = config.networking.hostName;
    })
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
      (mkCentralScrapeJob "prometheus" "127.0.0.1:${toString prometheus.port}")
      (mkCentralScrapeJob "loki" "${centralHost.network.lan.ipv4.host}:${toString centralHost.services.loki.port}")
      (mkCentralScrapeJob "grafana" "127.0.0.1:${toString centralHost.services.grafana.port}")
      probeScrapeConfig
    ]
    ++ lib.mapAttrsToList mkScrapeConfig exporterMetadata;
  };
}
