{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib;
  dashLib = import ./lib.nix { inherit lib; };
  # Every peer is probed over both families, so each panel holds v4 and v6
  # for the same machines and the two are directly comparable. `internet`
  # v6 stays down until IPv6 egress exists; that gap is the signal.
  probeLegend = "{{peer}} {{family}} {{host}}";
  smokepingQuantile =
    q: scope:
    "histogram_quantile(${q}, sum by (le, host, peer, family) (rate(smokeping_response_duration_seconds_bucket{scope=\"${scope}\"}[5m]))) * 1000";
  smokepingLoss =
    scope:
    "(1 - sum by (host, peer, family) (rate(smokeping_response_duration_seconds_count{scope=\"${scope}\"}[5m])) / sum by (host, peer, family) (rate(smokeping_requests_total{scope=\"${scope}\"}[5m]))) * 100";
  probeDuration =
    layers: scope: "probe_duration_seconds{layer=~\"${layers}\", scope=\"${scope}\"} * 1000";
in
dashLib.mkDashboard {
  uid = "internet";
  title = "Internet";
  panels = [
    (dashLib.mkStat {
      title = "Internet Probe Availability (24h)";
      expr = "avg by (family, layer) (avg_over_time(probe_success{scope=\"internet\"}[24h])) * 100";
      gridPos = dashLib.mkGridPos 0 0 12 5;
      legendFormat = "{{family}} {{layer}}";
      unit = "percent";
    })
    (dashLib.mkStat {
      title = "LAN Probe Availability (24h)";
      expr = "avg by (family, layer) (avg_over_time(probe_success{scope=\"lan\"}[24h])) * 100";
      gridPos = dashLib.mkGridPos 12 0 12 5;
      legendFormat = "{{family}} {{layer}}";
      unit = "percent";
    })
    (dashLib.mkStateTimeline {
      title = "Internet Reachability (v4 vs v6)";
      expr = "probe_success{scope=\"internet\"}";
      gridPos = dashLib.mkGridPos 0 5 12 8;
      legendFormat = "{{peer}} {{family}} {{layer}} {{host}}";
    })
    (dashLib.mkStateTimeline {
      title = "LAN Reachability (v4 vs v6)";
      expr = "probe_success{scope=\"lan\"}";
      gridPos = dashLib.mkGridPos 12 5 12 8;
      legendFormat = "{{peer}} {{family}} {{layer}} {{host}}";
    })
    (dashLib.mkStateTimeline {
      title = "Exporter Reachability";
      expr = "up{job=~\"blackbox|smokeping\"}";
      gridPos = dashLib.mkGridPos 0 13 24 6;
      legendFormat = "{{job}} {{host}}";
    })
    (dashLib.mkTimeseries {
      title = "Internet ICMP Probe Duration";
      expr = probeDuration "icmp|icmp6" "internet";
      gridPos = dashLib.mkGridPos 0 19 12 8;
      legendFormat = probeLegend;
      unit = "ms";
    })
    (dashLib.mkTimeseries {
      title = "LAN ICMP Probe Duration";
      expr = probeDuration "icmp|icmp6" "lan";
      gridPos = dashLib.mkGridPos 12 19 12 8;
      legendFormat = probeLegend;
      unit = "ms";
    })
    (dashLib.mkTimeseries {
      title = "Internet DNS Probe Duration";
      expr = probeDuration "dns|dns6" "internet";
      gridPos = dashLib.mkGridPos 0 27 12 8;
      legendFormat = probeLegend;
      unit = "ms";
    })
    (dashLib.mkTimeseries {
      title = "LAN DNS Probe Duration";
      expr = probeDuration "dns|dns6" "lan";
      gridPos = dashLib.mkGridPos 12 27 12 8;
      legendFormat = probeLegend;
      unit = "ms";
    })
    (dashLib.mkTimeseries {
      title = "Internet HTTPS Probe Duration";
      expr = probeDuration "http|http6" "internet";
      gridPos = dashLib.mkGridPos 0 35 24 8;
      legendFormat = probeLegend;
      unit = "ms";
    })
    (dashLib.mkTimeseries {
      title = "Internet ICMP Latency p50";
      expr = smokepingQuantile "0.50" "internet";
      gridPos = dashLib.mkGridPos 0 43 12 8;
      legendFormat = probeLegend;
      unit = "ms";
    })
    (dashLib.mkTimeseries {
      title = "LAN ICMP Latency p50";
      expr = smokepingQuantile "0.50" "lan";
      gridPos = dashLib.mkGridPos 12 43 12 8;
      legendFormat = probeLegend;
      unit = "ms";
    })
    (dashLib.mkTimeseries {
      title = "Internet ICMP Latency p95";
      expr = smokepingQuantile "0.95" "internet";
      gridPos = dashLib.mkGridPos 0 51 12 8;
      legendFormat = probeLegend;
      unit = "ms";
    })
    (dashLib.mkTimeseries {
      title = "LAN ICMP Latency p95";
      expr = smokepingQuantile "0.95" "lan";
      gridPos = dashLib.mkGridPos 12 51 12 8;
      legendFormat = probeLegend;
      unit = "ms";
    })
    (dashLib.mkTimeseries {
      title = "Internet ICMP Latency p99";
      expr = smokepingQuantile "0.99" "internet";
      gridPos = dashLib.mkGridPos 0 59 12 8;
      legendFormat = probeLegend;
      unit = "ms";
    })
    (dashLib.mkTimeseries {
      title = "LAN ICMP Latency p99";
      expr = smokepingQuantile "0.99" "lan";
      gridPos = dashLib.mkGridPos 12 59 12 8;
      legendFormat = probeLegend;
      unit = "ms";
    })
    (dashLib.mkTimeseries {
      title = "Internet ICMP Packet Loss";
      expr = smokepingLoss "internet";
      gridPos = dashLib.mkGridPos 0 67 12 8;
      legendFormat = probeLegend;
      unit = "percent";
    })
    (dashLib.mkTimeseries {
      title = "LAN ICMP Packet Loss";
      expr = smokepingLoss "lan";
      gridPos = dashLib.mkGridPos 12 67 12 8;
      legendFormat = probeLegend;
      unit = "percent";
    })
    (dashLib.mkStateTimeline {
      title = "Primary Uplink State";
      expr = "max by (host) (gateway_failover_primary_active)";
      gridPos = dashLib.mkGridPos 0 75 24 6;
      legendFormat = "{{host}}";
    })
    (dashLib.mkTimeseries {
      title = "IPv6 In";
      expr = "rate(node_netstat_Ip6_InOctets[5m])";
      gridPos = dashLib.mkGridPos 0 81 12 8;
      legendFormat = "{{host}}";
      unit = "Bps";
    })
    (dashLib.mkTimeseries {
      title = "IPv6 Out";
      expr = "rate(node_netstat_Ip6_OutOctets[5m])";
      gridPos = dashLib.mkGridPos 12 81 12 8;
      legendFormat = "{{host}}";
      unit = "Bps";
    })
  ];
}
