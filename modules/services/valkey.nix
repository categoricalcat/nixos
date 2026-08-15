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
      # unbound's cachedb module never removes data from the store itself;
      # cap memory and let valkey evict least-recently-used keys. Keys are
      # also TTL'd by unbound (redis-expire-records = "yes"). protected-mode
      # is off so unbound can reach it from yirukou over the LAN; the
      # valkey-guard nftables table is the access control.
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
