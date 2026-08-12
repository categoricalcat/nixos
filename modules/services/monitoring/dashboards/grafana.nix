{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib;
  dashLib = import ./lib.nix { inherit lib; };
in
dashLib.mkDashboard {
  uid = "grafana-self";
  title = "Grafana";
  panels = [
    (dashLib.mkTimeseries {
      title = "HTTP Requests Rate";
      expr = "sum by(status_code) (rate(grafana_http_request_duration_seconds_count[5m]))";
      gridPos = dashLib.mkGridPos 0 0 24 8;
      legendFormat = "{{status_code}}";
    })
    (dashLib.mkStat {
      title = "Active Dashboards";
      expr = "grafana_stat_dashboards";
      gridPos = dashLib.mkGridPos 0 8 12 4;
    })
  ];
}
