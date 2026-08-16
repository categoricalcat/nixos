{
  pkgs,
  config,
  lib,
  allAddresses,
  ...
}:

let
  # Shared DNS cache: single valkey on yifuwuqi, reached over the LAN from
  # both hosts. Survives unbound restarts (and reboots, via RDB snapshots)
  # and lets both instances share one cache.
  cacheDb = allAddresses.hosts.yifuwuqi.services.valkey;
in

{
  services.unbound = {
    enable = true;

    # nixpkgs builds the cachedb/redis module only when withRedis is set.
    package = pkgs.unbound-with-systemd.override { withRedis = true; };

    localControlSocketPath = "/run/unbound/unbound.ctl";
    settings = {
      server = {
        interface = [ "127.0.0.1" ];
        port = 5335;

        # Enable the cachedb module (second-level cache in valkey). It sits
        # between the in-memory cache and iterative resolution. Quoted: the
        # freeform renderer doesn't quote string values, and unbound reads
        # only the first token of an unquoted value.
        module-config = ''"validator cachedb iterator"'';

        access-control = [ "127.0.0.0/8 allow" ];

        # Performance & Threading (per-host, see addresses.nix dns.threads).
        # Home QPS doesn't need a thread per core; caches are shared slabhashes,
        # not per-thread, so fewer threads also mean fewer idle event loops.
        num-threads = allAddresses.hosts.${config.networking.hostName}.dns.threads or 4;
        # *-cache-slabs left unset: auto power-of-2 matching num-threads
        so-reuseport = "yes";

        # Cache Sizing (19 GiB RAM: config 900m -> ~2.2 GiB real usage)
        msg-cache-size = "300m";
        rrset-cache-size = "600m"; # 2x msg-cache-size (docs ratio)

        # Stale-while-revalidate: hold popular records long, refresh in background,
        # serve stale instantly on expiry, keep stale entries alive on refresh failure
        cache-min-ttl = 3600;
        cache-max-ttl = 604800; # 7 days, chosen cap (default 86400; not a hard max)
        prefetch = "yes";
        prefetch-key = "yes";
        serve-expired = "yes";
        serve-expired-ttl = 604800; # stale window aligned with cache-max-ttl
        serve-expired-ttl-reset = "yes";
        # failed refresh -> stale TTL resets to the
        # serve-expired-ttl window (SWR resilience)
        serve-expired-client-timeout = 0; # Serve stale immediately while revalidating
        # serve-expired-reply-ttl stays default 30 (RFC 8767 recommendation)

        # Concurrency (libevent build: no 1024 fd limit)
        outgoing-range = 8192;
        num-queries-per-thread = 4096;

        # Socket buffers: survive spikes on the busy LAN
        # (net.core.rmem_max/wmem_max are already >= 8 MiB on both hosts)
        so-rcvbuf = "4m";
        so-sndbuf = "4m";

        # Prefer the fastest servers; num 3 keeps the three fastest in the
        # candidate band so a hiccuping single server doesn't force retransmits.
        fast-server-permil = 1000;
        fast-server-num = 3;

        # Security Hardening & Privacy
        hide-identity = "yes";
        hide-version = "yes";
        qname-minimisation = "yes";
        aggressive-nsec = "yes";
        harden-glue = "yes";
        harden-dnssec-stripped = "yes";

        # Extended statistics (required by prometheus-unbound-exporter for
        # per-query-type counters and recursion time percentiles)
        extended-statistics = "yes";

        # Network & Fragmentation
        edns-buffer-size = 1232;
        do-ip4 = "yes";
        do-ip6 = "no"; # no IPv6 connectivity on either host (verified: no default v6 route)
        do-udp = "yes";
        do-tcp = "yes";
      };

      # Second-level cache (valkey, shared with the other unbound instance).
      # Low timeout so a hung valkey degrades to memory-cache-only resolution
      # instead of stalling DNS. secret-seed stays at the default on both
      # hosts so keys are identical and shareable.
      #
      # redis-expire-records: redis_store SETs with EX = clamped_ttl +
      # serve-expired-ttl (cachedb/redis.c: ttl += cfg->serve_expired_ttl),
      # i.e. 7d1h-14d. Keys thus expire exactly when the read side
      # (good_expiry_and_qinfo) would refuse them (older than expiry +
      # serve-expired-ttl). Turning EX off would desync L2 from the 7d stale
      # window and grow the db until the 1 GiB LRU cap.
      cachedb = {
        backend = "redis";
        redis-server-host = cacheDb.host;
        redis-server-port = cacheDb.port;
        redis-timeout = 100;
        redis-expire-records = "yes";
      };
    };
  };

  # unbound's cachedb redis_init probes SET-with-EX only once at startup and
  # never re-checks on reconnect (cachedb/redis.c). If it boots before the
  # valkey host is reachable, every store falls back to plain SET for the
  # process lifetime -- no key TTLs, LRU-only eviction. Wait for the network
  # (and the local valkey, when one exists) so redis_init succeeds.
  systemd.services.unbound = {
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
    ]
    ++ lib.optionals (config.services.redis.servers ? "") [ "redis.service" ];
  };
}
