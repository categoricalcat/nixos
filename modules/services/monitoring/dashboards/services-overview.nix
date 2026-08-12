{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib;
  dashLib = import ./lib.nix { inherit lib; };
in
dashLib.mkDashboard {
  uid = "services-overview";
  title = "Services Overview";
  panels = [
    (dashLib.mkStateTimeline {
      title = "Service States";
      expr = "node_systemd_unit_state{name=~\"forgejo.service|grafana.service|prometheus.service|loki.service|postgresql.service|nginx.service|fail2ban.service\", state=\"active\"}";
      gridPos = dashLib.mkGridPos 0 0 24 10;
      legendFormat = "{{name}}";
    })
  ];
}
