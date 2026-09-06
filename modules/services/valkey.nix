{
  pkgs,
  addresses,
  ...
}:

{
  services.redis = {
    package = pkgs.valkey;

    servers."" = {
      enable = true;
      # Loopback only. Every consumer is host-local and uses the unix socket;
      # nothing connects across the LAN, so this instance never needs to be
      # reachable off-box. unbound's cachedb is synchronous and blocks a worker
      # thread per query, which is why it must not traverse a link that can go
      # down (see modules/services/unbound.nix).
      bind = "127.0.0.1";
      port = addresses.services.valkey.port;
      # unbound SETs keys with EX = clamped DNS TTL + serve-expired-ttl
      # (7d1h-14d), so the db normally self-cleans. maxmemory + allkeys-lru
      # is the fallback cap for keys stored WITHOUT EX: unbound's redis_init
      # probes SET-with-EX once at startup and never re-probes on reconnect,
      # so booting before valkey is reachable means plain SET for the whole
      # process lifetime. Note allkeys-lru evicts across logical DBs,
      # including SearXNG's db1 on yifuwuqi.
      extraParams = [
        "--maxmemory"
        addresses.services.valkey.maxMemory
        "--maxmemory-policy"
        "allkeys-lru"
      ];
    };
  };
}
