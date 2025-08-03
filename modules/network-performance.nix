{ config, pkgs, lib, ... }:

{
  # Install essential network tools
  environment.systemPackages = with pkgs; [
    ethtool
    iperf3
    nethogs
    iftop
  ];

  # Optimized kernel parameters
  boot.kernel.sysctl = {
    # Network buffer tuning (adjusted for your 19GB RAM)
    "net.core.rmem_default" = 262144; # Increased from 131072
    "net.core.rmem_max" = 268435456; # Increased from 134217728
    "net.core.wmem_default" = 262144; # Increased from 131072
    "net.core.wmem_max" = 268435456; # Increased from 134217728
    "net.core.netdev_max_backlog" = 10000; # Increased from 5000 (for 1Gbps+)
    "net.core.netdev_budget" = 1200; # Increased from 600

    # TCP optimization (BBR-specific tuning)
    "net.ipv4.tcp_rmem" = "4096 262144 268435456";
    "net.ipv4.tcp_wmem" = "4096 262144 268435456";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_mtu_probing" = 2; # More aggressive probing (was 1)
    "net.ipv4.tcp_notsent_lowat" = 16384; # Reduce bufferbloat

    # Connection handling (optimized for server load)
    "net.core.somaxconn" = 4096; # Increased from 1024
    "net.ipv4.tcp_max_syn_backlog" = 8192; # Increased from 2048
    "net.ipv4.tcp_synack_retries" = 2; # Faster connection failure detection

    # Keepalive optimization
    "net.ipv4.tcp_keepalive_time" = 300; # Reduced from 600 (5 min)
    "net.ipv4.tcp_keepalive_probes" = 3; # Reduced from 6
    "net.ipv4.tcp_keepalive_intvl" = 30; # Reduced from 60

    # Memory management
    "vm.swappiness" = 10; # Reduce swap tendency
    "vm.vfs_cache_pressure" = 50; # Balance cache reclaim

    # Security-hardened TCP settings
    "net.ipv4.tcp_rfc1337" = 1; # Protect against TIME-WAIT attacks
    "net.ipv4.tcp_syncookies" = 1; # Enable SYN flood protection
  };

  # Essential kernel modules
  boot.kernelModules = lib.mkAfter [
    "tcp_bbr"
    "tcp_htcp" # Fallback congestion control
  ];

  # SSD-specific optimizations (for your Crucial P3 SSD)
  services.fstrim.enable = true;
  fileSystems."/".options = [
    "noatime"
    "nodiratime"
    "discard"
  ];

  # ZRAM swap configuration (more efficient than disk swap)
  zramSwap = {
    enable = true;
    memoryPercent = 100; # Uses 50% RAM by default
    algorithm = "zstd"; # Best compression for Ryzen
  };

}
