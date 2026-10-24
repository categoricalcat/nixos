{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib;
  dashLib = import ./lib.nix { inherit lib; };

  units =
    suffix: names: lib.concatMapStringsSep "|" (name: "${name}.${suffix}") (lib.splitString " " names);
  dailyTimers = units "timer" "podman-auto-update recyclarr attic-gc";
  weeklyTimers = units "timer" "nh-clean podman-prune fstrim";
  maintenanceServices = units "service" "nh-clean podman-prune podman-auto-update fstrim recyclarr attic-gc attic-closure-keeper security-audit-cve restart-gluetun";
  timerAge =
    timers: scale:
    "(time() - max by (host, name) (node_systemd_timer_last_trigger_seconds{name=~\"${timers}\"})) / ${toString scale}";
  steps =
    orange: red:
    [
      {
        color = "green";
        value = null;
      }
    ]
    ++ lib.optional (orange != null) {
      color = "orange";
      value = orange;
    }
    ++ [
      {
        color = "red";
        value = red;
      }
    ];
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
      expr = "sum by(host, name) (changes(node_systemd_unit_state{state=\"active\"}[1h])) > 0";
      gridPos = dashLib.mkGridPos 0 4 24 10;
      legendFormat = "{{host}} {{name}}";
      links = [
        (dashLib.mkLokiDataLink { })
      ];
    })
    (dashLib.mkStat {
      title = "Failed Maintenance Units";
      expr = "count(node_systemd_unit_state{state=\"failed\", name=~\"${maintenanceServices}\"} == 1) or vector(0)";
      gridPos = dashLib.mkGridPos 0 14 6 6;
      legendFormat = "Failed maintenance units";
      thresholds = steps null 1;
    })
    (dashLib.mkBarGauge {
      title = "Daily Maintenance: Last Run";
      expr = timerAge dailyTimers 3600;
      gridPos = dashLib.mkGridPos 6 14 9 6;
      legendFormat = "{{host}} {{name}}";
      unit = "h";
      max = 50;
      thresholds = steps 26 50;
    })
    (dashLib.mkBarGauge {
      title = "Weekly Maintenance: Last Run";
      expr = timerAge weeklyTimers 86400;
      gridPos = dashLib.mkGridPos 15 14 9 6;
      legendFormat = "{{host}} {{name}}";
      unit = "d";
      max = 15;
      thresholds = steps 8 15;
    })
  ];
}
