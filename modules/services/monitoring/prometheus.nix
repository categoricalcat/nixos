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
  mtls = config.yi.mtls;

  # Every exporter is reached through its host's ingress, path-prefixed by the
  # registry name, so no exporter port is ever dialled directly.
  exporterTarget = host: monitoringLib.ingressAddress allAddresses.hosts.${host};

  # Present the scraper's client certificate and verify the peer against the
  # internal CA. Targets are IP literals, verified through their IP SAN.
  ingressTls = lib.optionalAttrs mtls.enable {
    scheme = "https";
    tls_config = {
      ca_file = mtls.caFile;
      cert_file = mtls.clientCert;
      key_file = mtls.clientKey;
    };
  };

  mkScrapeConfig =
    exporter: spec:
    {
      job_name = exporter;
      metrics_path = "/${exporter}/metrics";
      static_configs = map (host: {
        targets = [ (exporterTarget host) ];
        labels = { inherit host; };
      }) (monitoringLib.resolveHosts monitoring spec.hosts);
      relabel_configs = monitoringLib.hostRelabelConfig;
    }
    // lib.optionalAttrs (spec ? scrapeInterval) {
      scrape_interval = spec.scrapeInterval;
    }
    // lib.optionalAttrs (spec ? metricRelabelConfigs) {
      metric_relabel_configs = spec.metricRelabelConfigs;
    }
    // ingressTls;

  # Jobs whose backend lives on the central host itself and has no registry
  # entry: they stay on loopback and stay plain HTTP.
  mkCentralScrapeJob =
    jobName: target: extra:
    {
      job_name = jobName;
      static_configs = [
        {
          targets = [ target ];
          labels.host = monitoring.centralHost;
        }
      ];
      relabel_configs = monitoringLib.hostRelabelConfig;
    }
    // extra;

  lokiJob = mkCentralScrapeJob "loki" (monitoringLib.ingressAddress centralHost) (
    { metrics_path = "/loki/metrics"; } // ingressTls
  );

  # One blackbox probe job for every (scrape host x probe), minus the host's
  # own peer entry: pinging itself measures nothing the adguard and unbound
  # exporters do not already cover. The blackbox module name equals the
  # probe's layer.
  probeScrapeConfig = {
    job_name = "probe";
    metrics_path = "/blackbox/probe";
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
          __tmp_address = exporterTarget host;
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
  }
  // ingressTls;
in
{
  imports = [ ../mtls.nix ];

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
    # The scrape TLS blocks point at the client key under /persist/keys/mtls,
    # which cannot exist inside the build sandbox; syntax-only keeps promtool
    # checking the config shape without demanding the runtime files.
    checkConfig = "syntax-only";

    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };

    scrapeConfigs = [
      (mkCentralScrapeJob "prometheus" "127.0.0.1:${toString prometheus.port}" { })
      lokiJob
      (mkCentralScrapeJob "grafana" "127.0.0.1:${toString centralHost.services.grafana.port}" { })
      probeScrapeConfig
    ]
    ++ lib.mapAttrsToList mkScrapeConfig exporterMetadata;
  };
}
