{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib;
  dashLib = import ./lib.nix { inherit lib; };
  v4Layers = ''layer=~"icmp|dns|http"'';
  v6Layers = ''layer=~"icmp6|dns6"'';
  # PromQL label regexes are fully anchored, so match the whole value.
  v4Target = ''target!~".*:.*"'';
  v6Target = ''target=~".*:.*"'';
  smokepingQuantile =
    q: family:
    "histogram_quantile(${q}, sum by (le, host, target) (rate(smokeping_response_duration_seconds_bucket{${family}}[5m]))) * 1000";
  smokepingLoss =
    family:
    "(1 - sum by (host, target) (rate(smokeping_response_duration_seconds_count{${family}}[5m])) / sum by (host, target) (rate(smokeping_requests_total{${family}}[5m]))) * 100";
in
dashLib.mkDashboard {
  uid = "internet";
  title = "Internet";
  panels = [
    (dashLib.mkStat {
      title = "IPv4 Probe Availability (24h)";
      expr = "avg by (host, layer) (avg_over_time(probe_success{${v4Layers}}[24h])) * 100";
      gridPos = dashLib.mkGridPos 0 0 12 5;
      legendFormat = "{{host}} {{layer}}";
      unit = "percent";
    })
    (dashLib.mkStat {
      title = "IPv6 Probe Availability (24h)";
      expr = "avg by (host, layer) (avg_over_time(probe_success{${v6Layers}}[24h])) * 100";
      gridPos = dashLib.mkGridPos 12 0 12 5;
      legendFormat = "{{host}} {{layer}}";
      unit = "percent";
    })
    (dashLib.mkStateTimeline {
      title = "IPv4 Layer Reachability";
      expr = "probe_success{${v4Layers}}";
      gridPos = dashLib.mkGridPos 0 5 12 8;
      legendFormat = "{{host}} {{layer}} {{instance}}";
    })
    (dashLib.mkStateTimeline {
      title = "IPv6 Layer Reachability";
      expr = "probe_success{${v6Layers}}";
      gridPos = dashLib.mkGridPos 12 5 12 8;
      legendFormat = "{{host}} {{layer}} {{instance}}";
    })
    (dashLib.mkStateTimeline {
      title = "Exporter Reachability";
      expr = "up{job=~\"blackbox|smokeping\"}";
      gridPos = dashLib.mkGridPos 0 13 24 6;
      legendFormat = "{{job}} {{host}}";
    })
    (dashLib.mkTimeseries {
      title = "IPv4 DNS / HTTP Probe Duration (ms)";
      expr = "probe_duration_seconds{layer=~\"dns|http\"} * 1000";
      gridPos = dashLib.mkGridPos 0 19 12 8;
      legendFormat = "{{host}} {{layer}} {{instance}}";
    })
    (dashLib.mkTimeseries {
      title = "IPv6 DNS Probe Duration (ms)";
      expr = "probe_duration_seconds{layer=\"dns6\"} * 1000";
      gridPos = dashLib.mkGridPos 12 19 12 8;
      legendFormat = "{{host}} {{layer}} {{instance}}";
    })
    (dashLib.mkTimeseries {
      title = "IPv4 ICMP Probe Duration (ms)";
      expr = "probe_duration_seconds{layer=\"icmp\"} * 1000";
      gridPos = dashLib.mkGridPos 0 27 12 8;
      legendFormat = "{{host}} {{layer}} {{instance}}";
    })
    (dashLib.mkTimeseries {
      title = "IPv6 ICMP Probe Duration (ms)";
      expr = "probe_duration_seconds{layer=\"icmp6\"} * 1000";
      gridPos = dashLib.mkGridPos 12 27 12 8;
      legendFormat = "{{host}} {{layer}} {{instance}}";
    })
    (dashLib.mkStateTimeline {
      title = "Primary Uplink State";
      expr = "max by (host) (gateway_failover_primary_active)";
      gridPos = dashLib.mkGridPos 0 35 24 6;
      legendFormat = "{{host}}";
    })
    (dashLib.mkTimeseries {
      title = "IPv4 ICMP Latency p50 (ms)";
      expr = smokepingQuantile "0.50" v4Target;
      gridPos = dashLib.mkGridPos 0 41 12 8;
      legendFormat = "{{host}} {{target}}";
    })
    (dashLib.mkTimeseries {
      title = "IPv6 ICMP Latency p50 (ms)";
      expr = smokepingQuantile "0.50" v6Target;
      gridPos = dashLib.mkGridPos 12 41 12 8;
      legendFormat = "{{host}} {{target}}";
    })
    (dashLib.mkTimeseries {
      title = "IPv4 ICMP Latency p95 (ms)";
      expr = smokepingQuantile "0.95" v4Target;
      gridPos = dashLib.mkGridPos 0 49 12 8;
      legendFormat = "{{host}} {{target}}";
    })
    (dashLib.mkTimeseries {
      title = "IPv6 ICMP Latency p95 (ms)";
      expr = smokepingQuantile "0.95" v6Target;
      gridPos = dashLib.mkGridPos 12 49 12 8;
      legendFormat = "{{host}} {{target}}";
    })
    (dashLib.mkTimeseries {
      title = "IPv4 ICMP Latency p99 (ms)";
      expr = smokepingQuantile "0.99" v4Target;
      gridPos = dashLib.mkGridPos 0 57 12 8;
      legendFormat = "{{host}} {{target}}";
    })
    (dashLib.mkTimeseries {
      title = "IPv6 ICMP Latency p99 (ms)";
      expr = smokepingQuantile "0.99" v6Target;
      gridPos = dashLib.mkGridPos 12 57 12 8;
      legendFormat = "{{host}} {{target}}";
    })
    (dashLib.mkTimeseries {
      title = "IPv4 ICMP Packet Loss (%)";
      expr = smokepingLoss v4Target;
      gridPos = dashLib.mkGridPos 0 65 12 8;
      legendFormat = "{{host}} {{target}}";
    })
    (dashLib.mkTimeseries {
      title = "IPv6 ICMP Packet Loss (%)";
      expr = smokepingLoss v6Target;
      gridPos = dashLib.mkGridPos 12 65 12 8;
      legendFormat = "{{host}} {{target}}";
    })
    (dashLib.mkTimeseries {
      title = "IPv6 In (B/s)";
      expr = "rate(node_netstat_Ip6_InOctets[5m])";
      gridPos = dashLib.mkGridPos 0 73 12 8;
      legendFormat = "{{host}}";
    })
    (dashLib.mkTimeseries {
      title = "IPv6 Out (B/s)";
      expr = "rate(node_netstat_Ip6_OutOctets[5m])";
      gridPos = dashLib.mkGridPos 12 73 12 8;
      legendFormat = "{{host}}";
    })
  ];
}
