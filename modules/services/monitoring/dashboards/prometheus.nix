{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib;
  dashLib = import ./lib.nix { inherit lib; };
in
dashLib.mkDashboard {
  uid = "prometheus-self";
  title = "Prometheus (Self)";
  panels = [
    (dashLib.mkTimeseries {
      title = "Scrape Duration";
      expr = "prometheus_target_interval_length_seconds";
      gridPos = dashLib.mkGridPos 0 0 12 8;
    })
    (dashLib.mkTimeseries {
      title = "Samples Ingested Rate";
      expr = "rate(prometheus_tsdb_head_samples_appended_total[5m])";
      gridPos = dashLib.mkGridPos 12 0 12 8;
    })
    (dashLib.mkStat {
      title = "Target Health";
      expr = "up";
      gridPos = dashLib.mkGridPos 0 8 24 4;
      legendFormat = "{{job}} ({{instance}})";
    })
  ];
}
