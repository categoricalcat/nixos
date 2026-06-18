_:

{
  boot.kernel.sysctl = {
    # Keep SYN floods from exhausting half-open TCP state.
    "net.ipv4.tcp_syncookies" = 1;

    # Avoid TIME-WAIT assassination hazards described by RFC 1337.
    "net.ipv4.tcp_rfc1337" = 1;

    # Do not learn IPv4/IPv6 routes from ICMP redirects.
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;

    # Ignore secure redirects and never emit redirects from these hosts.
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;

    # Reject sender-selected routing paths for IPv4 and IPv6.
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.default.accept_source_route" = 0;

    # Drop broadcast pings and noisy bogus ICMP error responses.
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    # Prefer keeping inode/dentry cache warm on general-purpose hosts.
    "vm.vfs_cache_pressure" = 50;
  };
}
