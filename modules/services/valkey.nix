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
      bind = addresses.services.valkey.host;
      port = addresses.services.valkey.port;
      # unbound SETs keys with EX = clamped DNS TTL + serve-expired-ttl
      # (7d1h-14d), so the db normally self-cleans. maxmemory + allkeys-lru
      # is the fallback cap for keys stored WITHOUT EX: unbound's redis_init
      # probes SET-with-EX once at startup and never re-probes on reconnect,
      # so booting before valkey is reachable means plain SET for the whole
      # process lifetime. Note allkeys-lru evicts across logical DBs,
      # including SearXNG's db1. protected-mode is off so unbound can reach
      # it from yirukou over the LAN; default-deny firewall permits yirukou gateway.
      extraParams = [
        "--maxmemory"
        "1gb"
        "--maxmemory-policy"
        "allkeys-lru"
        "--protected-mode"
        "no"
      ];
    };
  };
}
