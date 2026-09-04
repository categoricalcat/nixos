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
  # hardcoded --storage.tsdb.path), so relocate it with a bind mount. Declared
  # as a unit rather than fileSystems so a missing source dir fails only
  # prometheus.service, not local-fs.target/boot.
  systemd.mounts = [
    {
      what = dataDirs.prometheus;
      where = prometheusStateDir;
      type = "none";
      options = "bind";
      after = [ "systemd-tmpfiles-setup.service" ];
      before = [ "prometheus.service" ];
      requiredBy = [ "prometheus.service" ];
    }
  ];
}
