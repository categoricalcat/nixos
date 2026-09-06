{
  allAddresses,
  config,
  ...
}:

let
  inherit (allAddresses) monitoring;
  inherit (monitoring) dataRoot dataDirs;
  prometheusStateDir = "/var/lib/${config.services.prometheus.stateDir}";
in
{
  assertions = [
    {
      assertion = config.networking.hostName == monitoring.centralHost;
      message = "modules/services/monitoring/storage.nix: may only be imported on ${monitoring.centralHost}";
    }
  ];

  systemd.tmpfiles.rules = [
    "d ${dataRoot} 0755 root root -"
    "d ${dataDirs.prometheus} 0700 prometheus prometheus -"
    "d ${dataDirs.loki} 0750 loki loki -"
    "d ${dataDirs.grafana} 0750 grafana grafana -"
  ];

  # nixpkgs only exposes `stateDir` as a name below /var/lib (StateDirectory +
  # hardcoded --storage.tsdb.path), so redirect it inside the unit's mount
  # namespace. A standalone mount unit would deadlock local-fs.target at boot.
  systemd.services.prometheus.serviceConfig.BindPaths = [
    "${dataDirs.prometheus}:${prometheusStateDir}"
  ];
}
