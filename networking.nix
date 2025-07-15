# Networking configuration module

{ config, pkgs, ... }:

{
  networking = {
    hostName = "fufuwuqi";

    # Disable NetworkManager in favor of systemd-networkd
    networkmanager.enable = false;
    useNetworkd = true;
    useDHCP = false;

    # Firewall configuration
    firewall = {
      enable = true;
      allowedTCPPorts = [
        3000 # Development server
        3001 # Development server
        9000 # Additional service
        24212 # SSH port
      ];
    };
  };

  # Systemd network configuration for bonding
  systemd.network = {
    enable = true;

    # Network device configuration
    netdevs = {
      "10-bond0" = {
        netdevConfig = {
          Kind = "bond";
          Name = "bond0";
          # Uncomment to enable jumbo frames (if your network supports it)
          # MTU = 9000;
        };
        bondConfig = {
          Mode = "active-backup"; # 802.3ad mode causes link speed/duplex spam
          MIIMonitorSec = "0.100"; # Monitor link status
          PrimaryReselectPolicy = "better"; # Fixes recovery after plugging in USB eno1

          # Performance options for active-backup mode
          UpDelaySec = 0; # Bring slave up immediately
          DownDelaySec = 0; # Mark slave down immediately

          # Alternative modes for bandwidth aggregation (if switch supports it):
          # Mode = "balance-alb"; # Adaptive load balancing (no switch support needed)
          # Mode = "802.3ad"; # LACP (requires switch support)
          # LACPTransmitRate = "fast"; # For 802.3ad mode
        };
      };
    };

    # Network interface configuration
    networks = {
      "30-eno1" = {
        matchConfig.Name = "eno1";
        networkConfig = {
          Bond = "bond0";
          PrimarySlave = true; # Ensures eno1 route reactivates after USB ethernet adapter unplug/replug
        };
        # Performance: Offloading features are usually enabled by default
        # linkConfig = {
        #   # Uncomment if you want to enable jumbo frames
        #   # MTU = 9000;
        #   # Ensure gigabit speed (if having negotiation issues)
        #   # BitsPerSecond = "1G";
        # };
      };

      "30-enp4s0" = {
        matchConfig.Name = "enp4s0";
        networkConfig.Bond = "bond0";
        # IMPORTANT: This interface is only running at 100 Mbps!
        # Check cable quality and switch port configuration
        # linkConfig = {
        #   # Force gigabit if supported by hardware
        #   # BitsPerSecond = "1G";
        # };
      };

      "40-bond0" = {
        matchConfig.Name = "bond0";
        linkConfig.RequiredForOnline = "carrier";
        networkConfig.DHCP = "yes";
      };
    };
  };
}
