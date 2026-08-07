_:

{
  imports = [
    ../../../modules/networking/sysctl-base.nix
  ];

  boot.kernel.sysctl = {
    # Use larger default and maximum socket receive buffers for busy services.
    "net.core.rmem_default" = 262144;
    "net.core.rmem_max" = 67108864;

    # Match send buffers to the receive side for high-throughput TCP endpoints.
    "net.core.wmem_default" = 262144;
    "net.core.wmem_max" = 67108864;

    # Give the kernel more room and CPU budget for bursts arriving from NICs.
    "net.core.netdev_max_backlog" = 10000;
    "net.core.netdev_budget" = 1200;

    # Pair BBR with fq so paced TCP flows get per-flow queueing support.
    "net.core.default_qdisc" = "fq";

    # Let autotuned TCP receive windows grow for long-lived service traffic.
    "net.ipv4.tcp_rmem" = "4096 262144 67108864";

    # Let autotuned TCP send windows grow to the same 64 MiB ceiling.
    "net.ipv4.tcp_wmem" = "4096 262144 67108864";

    # Use BBR congestion control for hosted services on this endpoint.
    "net.ipv4.tcp_congestion_control" = "bbr";

    # Always probe for a working path MTU when black-hole PMTU is suspected.
    "net.ipv4.tcp_mtu_probing" = 2;

    # Keep unsent TCP data bounded so nginx/services see lower tail latency.
    "net.ipv4.tcp_notsent_lowat" = 16384;

    # Allow larger accept queues for services under connection bursts.
    "net.core.somaxconn" = 4096;

    # Hold more half-open SYNs before syncookies become necessary.
    "net.ipv4.tcp_max_syn_backlog" = 8192;

    # Fail unacknowledged SYN-ACKs quickly to avoid stale half-open state.
    "net.ipv4.tcp_synack_retries" = 2;

    # Detect dead TCP peers after five minutes of idleness.
    "net.ipv4.tcp_keepalive_time" = 300;

    # Send only a few keepalive probes before declaring the peer dead.
    "net.ipv4.tcp_keepalive_probes" = 3;

    # Space keepalive probes thirty seconds apart.
    "net.ipv4.tcp_keepalive_intvl" = 30;

    "vm.swappiness" = 180;

    # Avoid aggressive watermark boosting that can over-reclaim with zram.
    "vm.watermark_boost_factor" = 0;

    # Keep the kernel's free-memory watermark scaling conservative.
    "vm.watermark_scale_factor" = 100;

    # Swap individual pages instead of clustering reads around zram.
    "vm.page-cluster" = 0;
  };

  boot.kernelModules = [
    "tcp_bbr"
  ];
}
