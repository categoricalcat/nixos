{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib;
  dashLib = import ./lib.nix { inherit lib; };
in
dashLib.mkDashboard {
  uid = "systemd-units";
  title = "Systemd Units";
  panels = [
    (dashLib.mkStat {
      title = "Failed Units";
      expr = "count(node_systemd_unit_state{state=\"failed\"})";
      gridPos = dashLib.mkGridPos 0 0 12 4;
      legendFormat = "Failed units";
    })
    (dashLib.mkStat {
      title = "Active Units";
      expr = "count(node_systemd_unit_state{state=\"active\"})";
      gridPos = dashLib.mkGridPos 12 0 12 4;
      legendFormat = "Active units";
    })
    (dashLib.mkTimeseries {
      title = "Unit State Changes / Restarts";
      expr = "sum by(name) (changes(node_systemd_unit_state{state=\"active\"}[1h])) > 0";
      gridPos = dashLib.mkGridPos 0 4 24 10;
      legendFormat = "{{name}}";
    })
  ];
}
