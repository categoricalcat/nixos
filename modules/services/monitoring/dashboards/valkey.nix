{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib;
  dashLib = import ./lib.nix { inherit lib; };
in
dashLib.mkDashboard {
  uid = "valkey";
  title = "Valkey (DNS Cache)";
  panels = [
    (dashLib.mkStat {
      title = "DNS Cache Entries (db0)";
      expr = "redis_db_keys{db=\"db0\"}";
      gridPos = dashLib.mkGridPos 0 0 6 4;
      unit = "short";
    })
    (dashLib.mkGauge {
      title = "Cache Hit Ratio";
      expr = "redis_keyspace_hits_total / (redis_keyspace_hits_total + redis_keyspace_misses_total) * 100";
      gridPos = dashLib.mkGridPos 6 0 6 4;
      unit = "percent";
    })
    (dashLib.mkStat {
      title = "Memory Used";
      expr = "redis_memory_used_bytes";
      gridPos = dashLib.mkGridPos 12 0 6 4;
      unit = "bytes";
    })
    (dashLib.mkStat {
      title = "Keys Expiring (db0)";
      expr = "redis_db_keys_expiring{db=\"db0\"}";
      gridPos = dashLib.mkGridPos 18 0 6 4;
      unit = "short";
    })
    (dashLib.mkTimeseries {
      title = "Memory Used (MiB)";
      expr = "redis_memory_used_bytes / 1024 / 1024";
      gridPos = dashLib.mkGridPos 0 4 12 8;
      legendFormat = "used";
    })
    (dashLib.mkTimeseries {
      title = "Memory Max (MiB)";
      expr = "redis_memory_max_bytes / 1024 / 1024";
      gridPos = dashLib.mkGridPos 12 4 12 8;
      legendFormat = "max";
    })
    (dashLib.mkTimeseries {
      title = "Evictions + Expired / sec";
      expr = "rate(redis_evicted_keys_total[5m]) + rate(redis_expired_keys_total[5m])";
      gridPos = dashLib.mkGridPos 0 12 12 8;
      legendFormat = "rate";
    })
    (dashLib.mkTimeseries {
      title = "Cache Hits / sec";
      expr = "rate(redis_keyspace_hits_total[5m])";
      gridPos = dashLib.mkGridPos 12 12 12 8;
      legendFormat = "hits";
    })
  ];
}
