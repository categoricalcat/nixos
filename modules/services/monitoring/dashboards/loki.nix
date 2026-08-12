{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib;
  dashLib = import ./lib.nix { inherit lib; };
in
dashLib.mkDashboard {
  uid = "loki-self";
  title = "Loki";
  panels = [
    (dashLib.mkTimeseries {
      title = "Ingestion Rate";
      expr = "rate(loki_distributor_bytes_received_total[5m])";
      gridPos = dashLib.mkGridPos 0 0 12 8;
    })
    (dashLib.mkTimeseries {
      title = "Request Rates";
      expr = "sum by(route) (rate(loki_request_duration_seconds_count[5m]))";
      gridPos = dashLib.mkGridPos 12 0 12 8;
      legendFormat = "{{route}}";
    })
  ];
}
