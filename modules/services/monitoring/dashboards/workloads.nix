_:
let
  dashLib = import ./lib.nix;

  mkStatRow =
    panels:
    builtins.genList (
      index:
      dashLib.mkStat (
        builtins.elemAt panels index
        // {
          gridPos = dashLib.mkGridPos (index * 6) 0 6 4;
        }
      )
    ) (builtins.length panels);

  mkTopRow =
    {
      y,
      groupLabel,
      panels,
    }:
    builtins.genList (
      index:
      dashLib.mkTimeseries (
        builtins.elemAt panels index
        // {
          gridPos = dashLib.mkGridPos (index * 8) y 8 8;
          legendFormat = "{{host}} {{${groupLabel}}}";
        }
      )
    ) (builtins.length panels);

  top10 = labels: expression: "topk(10, sum by(${labels}) (${expression}))";

  summaryPanels = [
    {
      title = "Workload Targets Down";
      expr = "count(up{job=~\"cadvisor|process|systemd\"} == 0) or vector(0)";
      legendFormat = "Down";
      thresholds = dashLib.alertThresholds;
    }
    {
      title = "Podman Restarts (15m)";
      expr = "sum(increase(systemd_service_restart_total{name=~\"podman-.+[.]service\"}[15m])) or vector(0)";
      legendFormat = "Restarts";
      thresholds = dashLib.alertThresholds;
    }
    {
      title = "Running Containers";
      expr = "count(container_last_seen{name!=\"\"}) or vector(0)";
      legendFormat = "Containers";
    }
    {
      title = "Tracked Programs";
      expr = "count(namedprocess_namegroup_num_procs > 0) or vector(0)";
      legendFormat = "Groups";
    }
  ];

  containerPanels = [
    {
      title = "Top Containers: CPU";
      expr = top10 "host, name" "rate(container_cpu_usage_seconds_total{name!=\"\"}[5m])";
      unit = "cores";
    }
    {
      title = "Top Containers: Memory";
      expr = top10 "host, name" "container_memory_working_set_bytes{name!=\"\"}";
      unit = "bytes";
    }
    {
      title = "Top Containers: Network";
      expr = top10 "host, name" "rate(container_network_receive_bytes_total{name!=\"\"}[5m]) + rate(container_network_transmit_bytes_total{name!=\"\"}[5m])";
      unit = "Bps";
    }
  ];

  programPanels = [
    {
      title = "Top Programs: CPU";
      expr = top10 "host, groupname" "rate(namedprocess_namegroup_cpu_seconds_total[5m])";
      unit = "cores";
    }
    {
      title = "Top Programs: Resident Memory";
      expr = top10 "host, groupname" "namedprocess_namegroup_memory_bytes{memtype=\"resident\"}";
      unit = "bytes";
    }
    {
      title = "Top Programs: Disk I/O";
      expr = top10 "host, groupname" "rate(namedprocess_namegroup_read_bytes_total[5m]) + rate(namedprocess_namegroup_write_bytes_total[5m])";
      unit = "Bps";
    }
  ];
in
dashLib.mkDashboard {
  uid = "workloads";
  title = "Workloads";
  panels =
    mkStatRow summaryPanels
    ++ mkTopRow {
      y = 4;
      groupLabel = "name";
      panels = containerPanels;
    }
    ++ mkTopRow {
      y = 12;
      groupLabel = "groupname";
      panels = programPanels;
    }
    ++ [
      (dashLib.mkTimeseries {
        title = "Top Systemd Units: Network";
        expr = top10 "host, name" "rate(systemd_service_ip_ingress_bytes[5m]) + rate(systemd_service_ip_egress_bytes[5m])";
        gridPos = dashLib.mkGridPos 0 20 12 8;
        legendFormat = "{{host}} {{name}}";
        unit = "Bps";
        links = dashLib.defaultLokiLinks;
      })
      (dashLib.mkTimeseries {
        title = "Systemd Unit Restarts (1h)";
        expr = "${top10 "host, name" "increase(systemd_service_restart_total[1h])"} > 0";
        gridPos = dashLib.mkGridPos 12 20 12 8;
        legendFormat = "{{host}} {{name}}";
        links = dashLib.defaultLokiLinks;
      })
      (dashLib.mkTimeseries {
        title = "Top Containers: Block I/O";
        expr = top10 "host, name" "rate(container_fs_reads_bytes_total{name!=\"\"}[5m]) + rate(container_fs_writes_bytes_total{name!=\"\"}[5m])";
        gridPos = dashLib.mkGridPos 0 28 24 8;
        legendFormat = "{{host}} {{name}}";
        unit = "Bps";
      })
    ];
}
