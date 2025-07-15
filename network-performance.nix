# Network Performance Tuning Module

{ config, pkgs, ... }:

{
  # Install network diagnostic tools
  environment.systemPackages = with pkgs; [
    ethtool
    iperf3
    nethogs
    iftop
  ];

  # Kernel parameters for network performance
  boot.kernel.sysctl = {
    # Increase network buffer sizes
    "net.core.rmem_default" = 131072;
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_default" = 131072;
    "net.core.wmem_max" = 134217728;
    "net.core.netdev_max_backlog" = 5000;
    "net.core.netdev_budget" = 600;

    # TCP optimization
    "net.ipv4.tcp_rmem" = "4096 131072 134217728";
    "net.ipv4.tcp_wmem" = "4096 65536 134217728";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_mtu_probing" = 1;
    "net.ipv4.tcp_timestamps" = 1;
    "net.ipv4.tcp_sack" = 1;
    "net.ipv4.tcp_window_scaling" = 1;

    # Enable TCP Fast Open
    "net.ipv4.tcp_fastopen" = 3;

    # Increase the maximum number of connections
    "net.core.somaxconn" = 1024;
    "net.ipv4.tcp_max_syn_backlog" = 2048;

    # Reduce TCP keepalive time for faster detection of dead connections
    "net.ipv4.tcp_keepalive_time" = 600;
    "net.ipv4.tcp_keepalive_intvl" = 60;
    "net.ipv4.tcp_keepalive_probes" = 6;

    # SSH-specific optimizations
    # Allow TCP to use all available bandwidth (useful for SSH bulk transfers)
    "net.ipv4.tcp_slow_start_after_idle" = 0;

    # Optimize for low latency (good for interactive SSH)
    "net.ipv4.tcp_low_latency" = 1;

    # Increase IP packet priority for SSH (port 24212)
    # Note: This requires iptables rules to mark packets
    "net.ipv4.ip_local_port_range" = "32768 65535";
  };

  # Enable BBR congestion control (requires kernel module)
  boot.kernelModules = [ "tcp_bbr" ];

  # Optional: QoS for SSH traffic using tc (traffic control)
  # This gives SSH traffic higher priority
  networking.firewall.extraCommands = ''
    # Mark SSH packets for QoS (port 24212)
    iptables -t mangle -A OUTPUT -p tcp --sport 24212 -j MARK --set-mark 0x1
    iptables -t mangle -A OUTPUT -p tcp --dport 24212 -j MARK --set-mark 0x1
  '';
}
