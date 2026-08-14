_:

{
  services.unbound = {
    enable = true;

    localControlSocketPath = "/run/unbound/unbound.ctl";
    settings = {
      server = {
        interface = [ "127.0.0.1" ];
        port = 5335;

        access-control = [ "127.0.0.0/8 allow" ];

        # Performance & Threading (16 threads for the 16-core router)
        num-threads = 16;
        # *-cache-slabs left unset: auto power-of-2 matching num-threads
        so-reuseport = "yes";

        # Cache Sizing (19 GiB RAM: config 900m -> ~2.2 GiB real usage)
        msg-cache-size = "300m";
        rrset-cache-size = "600m"; # 2x msg-cache-size (docs ratio)

        # Stale-while-revalidate: hold popular records long, refresh in background,
        # serve stale instantly on expiry, keep stale entries alive on refresh failure
        cache-min-ttl = 3600;
        cache-max-ttl = 604800; # 7 days, unbound maximum
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

        # Always use only the lowest-RTT nameserver; prefetch/serve-expired still explore.
        fast-server-permil = 1000;
        fast-server-num = 1;

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
        do-ip6 = "yes";
        do-udp = "yes";
        do-tcp = "yes";
      };
    };
  };
}
