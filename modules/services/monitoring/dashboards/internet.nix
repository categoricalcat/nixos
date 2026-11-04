_:
let
  dashLib = import ./lib.nix;
  # Dual-stack peers plot v4 and v6 together. `internet` v6 stays down until
  # IPv6 egress exists; a peer with no `v6` never grows a v6 series.
  probeLegend = "{{peer}} {{family}} {{host}}";
  # `internet` peers are a failure-domain ladder, so their legends lead with
  # the rung: sorted, the series read in diagnostic order and the first one
  # that breaks localises the outage. `tier` is constant per peer, so adding
  # it to the aggregations below does not change their grouping.
  tierLegend = "{{tier}} {{peer}} {{family}} {{host}}";
  scopes = [
    {
      name = "Internet";
      value = "internet";
      x = 0;
      legend = tierLegend;
      reachabilityLegend = "{{tier}} {{peer}} {{family}} {{layer}} {{host}}";
    }
    {
      name = "LAN";
      value = "lan";
      x = 12;
      legend = probeLegend;
      reachabilityLegend = "{{peer}} {{family}} {{layer}} {{host}}";
    }
  ];
  mkScopePair =
    {
      panel,
      y,
      height,
      attrs,
    }:
    map (
      scope:
      panel (
        attrs scope
        // {
          gridPos = dashLib.mkGridPos scope.x y 12 height;
        }
      )
    ) scopes;
  mkScopeTimeseries =
    {
      title,
      expr,
      y,
      unit,
    }:
    mkScopePair {
      panel = dashLib.mkTimeseries;
      inherit y;
      height = 8;
      attrs = scope: {
        title = "${scope.name} ${title}";
        expr = expr scope.value;
        legendFormat = scope.legend;
        inherit unit;
      };
    };
  smokepingQuantile =
    q: scope:
    "histogram_quantile(${q}, sum by (le, host, peer, tier, family) (rate(smokeping_response_duration_seconds_bucket{scope=\"${scope}\"}[5m]))) * 1000";
  smokepingLoss =
    scope:
    "(1 - sum by (host, peer, tier, family) (rate(smokeping_response_duration_seconds_count{scope=\"${scope}\"}[5m])) / sum by (host, peer, tier, family) (rate(smokeping_requests_total{scope=\"${scope}\"}[5m]))) * 100";
  probeDuration =
    layers: scope: "probe_duration_seconds{layer=~\"${layers}\", scope=\"${scope}\"} * 1000";
in
dashLib.mkDashboard {
  uid = "internet";
  title = "Internet";
  panels =
    mkScopePair {
      panel = dashLib.mkStat;
      y = 0;
      height = 5;
      attrs = scope: {
        title = "${scope.name} Probe Availability (24h)";
        expr = "avg by (family, layer) (avg_over_time(probe_success{scope=\"${scope.value}\"}[24h])) * 100";
        legendFormat = "{{family}} {{layer}}";
        unit = "percent";
      };
    }
    ++ mkScopePair {
      panel = dashLib.mkStateTimeline;
      y = 5;
      height = 8;
      attrs = scope: {
        title = "${scope.name} Reachability (v4 vs v6)";
        expr = "probe_success{scope=\"${scope.value}\"}";
        legendFormat = scope.reachabilityLegend;
      };
    }
    ++ [
      (dashLib.mkStateTimeline {
        title = "Exporter Reachability";
        expr = "up{job=~\"blackbox|smokeping\"}";
        gridPos = dashLib.mkGridPos 0 13 24 6;
        legendFormat = "{{job}} {{host}}";
      })
    ]
    ++ mkScopeTimeseries {
      title = "ICMP Probe Duration";
      expr = probeDuration "icmp|icmp6";
      y = 19;
      unit = "ms";
    }
    ++ mkScopeTimeseries {
      title = "DNS Probe Duration";
      expr = probeDuration "dns|dns6";
      y = 27;
      unit = "ms";
    }
    ++ [
      (dashLib.mkTimeseries {
        title = "Internet HTTPS Probe Duration";
        expr = probeDuration "http|http6" "internet";
        gridPos = dashLib.mkGridPos 0 35 24 8;
        legendFormat = tierLegend;
        unit = "ms";
      })
    ]
    ++ mkScopeTimeseries {
      title = "ICMP Latency p50";
      expr = smokepingQuantile "0.50";
      y = 43;
      unit = "ms";
    }
    ++ mkScopeTimeseries {
      title = "ICMP Latency p95";
      expr = smokepingQuantile "0.95";
      y = 51;
      unit = "ms";
    }
    ++ mkScopeTimeseries {
      title = "ICMP Latency p99";
      expr = smokepingQuantile "0.99";
      y = 59;
      unit = "ms";
    }
    ++ mkScopeTimeseries {
      title = "ICMP Packet Loss";
      expr = smokepingLoss;
      y = 67;
      unit = "percent";
    }
    ++ [
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
