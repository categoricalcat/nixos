_:
let
  dashLib = import ./lib.nix;

  mkTimeseriesRow =
    y: panels:
    builtins.genList (
      index:
      dashLib.mkTimeseries (
        builtins.elemAt panels index
        // {
          gridPos = dashLib.mkGridPos (index * 12) y 12 8;
          legendFormat = "{{host}}";
        }
      )
    ) (builtins.length panels);
in
dashLib.mkDashboard {
  uid = "valkey";
  title = "Valkey (DNS Cache)";
  panels = [
    (dashLib.mkStat {
      title = "DNS Cache Entries (db0)";
      expr = "redis_db_keys{db=\"db0\"}";
      gridPos = dashLib.mkGridPos 0 0 6 4;
      legendFormat = "{{host}}";
      unit = "short";
    })
    (dashLib.mkGauge {
      title = "Cache Hit Ratio";
      expr = "redis_keyspace_hits_total / (redis_keyspace_hits_total + redis_keyspace_misses_total) * 100";
      gridPos = dashLib.mkGridPos 6 0 6 4;
      legendFormat = "{{host}}";
      unit = "percent";
    })
    (dashLib.mkStat {
      title = "Memory Used";
      expr = "redis_memory_used_bytes";
      gridPos = dashLib.mkGridPos 12 0 6 4;
      legendFormat = "{{host}}";
      unit = "bytes";
    })
    (dashLib.mkStat {
      title = "Keys Expiring (db0)";
      expr = "redis_db_keys_expiring{db=\"db0\"}";
      gridPos = dashLib.mkGridPos 18 0 6 4;
      legendFormat = "{{host}}";
      unit = "short";
    })
  ]
  ++ mkTimeseriesRow 4 [
    {
      title = "Memory Used (MiB)";
      expr = "redis_memory_used_bytes / 1024 / 1024";
    }
    {
      title = "Memory Max (MiB)";
      expr = "redis_memory_max_bytes / 1024 / 1024";
    }
  ]
  ++ mkTimeseriesRow 12 [
    {
      title = "Evictions + Expired / sec";
      expr = "rate(redis_evicted_keys_total[5m]) + rate(redis_expired_keys_total[5m])";
    }
    {
      title = "Cache Hits / sec";
      expr = "rate(redis_keyspace_hits_total[5m])";
    }
  ];
}
