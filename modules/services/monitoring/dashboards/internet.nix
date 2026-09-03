{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib;
  dashLib = import ./lib.nix { inherit lib; };
in
dashLib.mkDashboard {
  uid = "internet";
  title = "Internet";
  panels = [
    (dashLib.mkStat {
      title = "Probe Availability (24h)";
      expr = "avg by (host, layer) (avg_over_time(probe_success[24h])) * 100";
      gridPos = dashLib.mkGridPos 0 0 24 5;
      legendFormat = "{{host}} {{layer}}";
      unit = "percent";
    })
    (dashLib.mkStateTimeline {
      title = "Layer Reachability";
      expr = "probe_success";
      gridPos = dashLib.mkGridPos 0 5 24 8;
      legendFormat = "{{host}} {{layer}} {{instance}}";
    })
    (dashLib.mkStateTimeline {
      title = "Exporter Reachability";
      expr = "up{job=~\"blackbox|smokeping\"}";
      gridPos = dashLib.mkGridPos 0 13 24 6;
      legendFormat = "{{job}} {{host}}";
    })
    (dashLib.mkTimeseries {
      title = "DNS / HTTP Probe Duration (ms)";
      expr = "probe_duration_seconds{layer=~\"dns|http\"} * 1000";
      gridPos = dashLib.mkGridPos 0 19 24 8;
      legendFormat = "{{host}} {{layer}} {{instance}}";
    })
    (dashLib.mkStateTimeline {
      title = "Primary Uplink State";
      expr = "max by (host) (gateway_failover_primary_active)";
      gridPos = dashLib.mkGridPos 0 27 24 6;
      legendFormat = "{{host}}";
    })
    (dashLib.mkTimeseries {
      title = "ICMP Latency p50 (ms)";
      expr = "histogram_quantile(0.50, sum by (le, host, target) (rate(smokeping_response_duration_seconds_bucket[5m]))) * 1000";
      gridPos = dashLib.mkGridPos 0 33 8 8;
      legendFormat = "{{host}} {{target}}";
    })
    (dashLib.mkTimeseries {
      title = "ICMP Latency p95 (ms)";
      expr = "histogram_quantile(0.95, sum by (le, host, target) (rate(smokeping_response_duration_seconds_bucket[5m]))) * 1000";
      gridPos = dashLib.mkGridPos 8 33 8 8;
      legendFormat = "{{host}} {{target}}";
    })
    (dashLib.mkTimeseries {
      title = "ICMP Latency p99 (ms)";
      expr = "histogram_quantile(0.99, sum by (le, host, target) (rate(smokeping_response_duration_seconds_bucket[5m]))) * 1000";
      gridPos = dashLib.mkGridPos 16 33 8 8;
      legendFormat = "{{host}} {{target}}";
    })
    (dashLib.mkTimeseries {
      title = "ICMP Packet Loss (%)";
      expr = "(1 - sum by (host, target) (rate(smokeping_response_duration_seconds_count[5m])) / sum by (host, target) (rate(smokeping_requests_total[5m]))) * 100";
      gridPos = dashLib.mkGridPos 0 41 24 8;
      legendFormat = "{{host}} {{target}}";
    })
  ];
}
