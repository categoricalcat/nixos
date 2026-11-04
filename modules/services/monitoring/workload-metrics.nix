{
  allAddresses,
  config,
  ...
}:

let
  inherit (allAddresses) monitoring;
  monitoringLib = import ./lib.nix;
  hostName = config.networking.hostName;
in
{
  assertions = [
    (monitoringLib.mkCentralHostAssertion {
      modulePath = "modules/services/monitoring/workload-metrics.nix";
      inherit monitoring hostName;
    })
  ];

  services = {
    cadvisor = {
      enable = true;
      listenAddress = "127.0.0.1";
      extraOptions = [
        # `dockerSocket.enable` aliases docker.sock to Podman, and cAdvisor's
        # Docker handler would claim the libpod scopes and fail.
        "--docker=unix:///dev/null"
        "--housekeeping_interval=15s"
        "--podman=unix:///run/podman/podman.sock"
      ];
    };

    prometheus = {
      ruleFiles = [ ./rules/workloads.yml ];
      scrapeConfigs = [
        {
          job_name = "cadvisor";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString config.services.cadvisor.port}" ];
              labels.host = hostName;
            }
          ];
          relabel_configs = monitoringLib.hostRelabelConfig;
          # cAdvisor also exports crun's inner `container` cgroup under the
          # scope id plus a trailing `/`; drop it so each container counts once.
          metric_relabel_configs = [
            {
              source_labels = [ "id" ];
              regex = ".+/";
              action = "drop";
            }
          ];
        }
      ];
    };
  };

  systemd.services.cadvisor = monitoringLib.mkWantsAfter [ "podman.socket" ];
}
