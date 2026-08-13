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

        # Performance & Threading (4 threads for the system)
        num-threads = 4;
        msg-cache-slabs = 4;
        rrset-cache-slabs = 4;
        infra-cache-slabs = 4;
        key-cache-slabs = 4;
        so-reuseport = "yes";

        # Cache Sizing
        msg-cache-size = "50m";
        rrset-cache-size = "100m"; # Typically 2x msg-cache-size

        cache-min-ttl = 300;
        cache-max-ttl = 86400;
        prefetch = "yes";
        prefetch-key = "yes";
        serve-expired = "yes";
        serve-expired-ttl = 86400; # 1 day limit for stale records
        serve-expired-client-timeout = 0; # Serve stale immediately while revalidating

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
