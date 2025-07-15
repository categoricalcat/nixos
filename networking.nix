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
        };
        bondConfig = {
          Mode = "active-backup"; # 802.3ad mode causes link speed/duplex spam
          MIIMonitorSec = "0.100"; # Monitor link status
          PrimaryReselectPolicy = "better"; # Fixes recovery after plugging in USB eno1
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
      };

      "30-enp4s0" = {
        matchConfig.Name = "enp4s0";
        networkConfig.Bond = "bond0";
      };

      "40-bond0" = {
        matchConfig.Name = "bond0";
        linkConfig.RequiredForOnline = "carrier";
        networkConfig.DHCP = "yes";
      };
    };
  };
}
