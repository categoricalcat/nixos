{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib;
  dashLib = import ./lib.nix { inherit lib; };
in
dashLib.mkDashboard {
  uid = "postgres";
  title = "PostgreSQL";
  panels = [
    (dashLib.mkTimeseries {
      title = "Active Connections";
      expr = "pg_stat_activity_count{state=\"active\"}";
      gridPos = dashLib.mkGridPos 0 0 12 8;
      legendFormat = "{{datname}}";
    })
    (dashLib.mkTimeseries {
      title = "Transactions / sec";
      expr = "rate(pg_stat_database_xact_commit[5m])";
      gridPos = dashLib.mkGridPos 12 0 12 8;
      legendFormat = "{{datname}}";
    })
  ];
}
