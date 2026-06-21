_:

{
  imports = [
    ../../../modules/networking/sysctl-base.nix
  ];

  boot.kernel.sysctl = {
    # IPv4 routing is owned by yirukou. IPv6 forwarding waits for a PD design.
    "net.ipv4.ip_forward" = 1;

    # Enable IPv4 forwarding on all interfaces, including future router ports.
    "net.ipv4.conf.all.forwarding" = 1;

    # Loose RPF works with WAN failover, and future fwmark/PBR.
    # nftables bogon and state rules are the router's security boundary.
    "net.ipv4.conf.all.rp_filter" = 2;

    # Apply loose RPF to interfaces created after boot unless overridden.
    "net.ipv4.conf.default.rp_filter" = 2;

    # Use fair queueing with CoDel so router egress resists bufferbloat.
    "net.core.default_qdisc" = "fq_codel";

    # Keep router socket buffers modest while still allowing burst absorption.
    "net.core.rmem_default" = 262144;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_default" = 262144;
    "net.core.wmem_max" = 16777216;

    # Size packet backlog and poll budget for forwarding, not service hosting.
    "net.core.netdev_max_backlog" = 5000;
    "net.core.netdev_budget" = 600;

    # Reserve conntrack capacity for NAT, forwarding, and tunnel flows.
    "net.netfilter.nf_conntrack_max" = 262144;

    # Keep automatic conntrack helpers disabled; nftables should opt in.
    "net.netfilter.nf_conntrack_helper" = 0;

    # Retire generic conntrack entries quickly on a gateway.
    "net.netfilter.nf_conntrack_generic_timeout" = 120;

    # Keep one-shot UDP state short to avoid stale NAT mappings.
    "net.netfilter.nf_conntrack_udp_timeout" = 30;

    # Allow active UDP streams to survive normal packet spacing.
    "net.netfilter.nf_conntrack_udp_timeout_stream" = 180;

    # Shorten established TCP tracking from the kernel default for router scale.
    "net.netfilter.nf_conntrack_tcp_timeout_established" = 7440;

    # Trim TCP teardown states so dead flows leave conntrack promptly.
    "net.netfilter.nf_conntrack_tcp_timeout_close_wait" = 60;
    "net.netfilter.nf_conntrack_tcp_timeout_fin_wait" = 120;
    "net.netfilter.nf_conntrack_tcp_timeout_time_wait" = 120;

    # Rate-limit ICMP replies while preserving diagnostics.
    "net.ipv4.icmp_ratelimit" = 100;

    # Accept fwmark-aware TCP replies for policy-routed flows.
    "net.ipv4.tcp_fwmark_accept" = 1;

    # Avoid ECMP nexthops whose neighbor state is already failed.
    "net.ipv4.fib_multipath_use_neigh" = 1;

    # Prefer physical RAM over swap on this router.
    "vm.swappiness" = 10;

    # Keep a 64 MiB free-memory reserve for network and interrupt pressure.
    "vm.min_free_kbytes" = 65536;
  };
}
