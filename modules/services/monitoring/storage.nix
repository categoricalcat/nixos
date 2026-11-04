{
  allAddresses,
  config,
  ...
}:

let
  inherit (allAddresses) monitoring;
  monitoringLib = import ./lib.nix;
  inherit (monitoring) dataRoot dataDirs;
  prometheusStateDir = "/var/lib/${config.services.prometheus.stateDir}";
in
{
  assertions = [
    (monitoringLib.mkCentralHostAssertion {
      modulePath = "modules/services/monitoring/storage.nix";
      inherit monitoring;
      hostName = config.networking.hostName;
    })
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
