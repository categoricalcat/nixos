# Networking configuration module

{ config, pkgs, ... }:

{
  networking = {
    hostName = "fufuwuqi";

    networkmanager.enable = false;
    useNetworkd = true;
    useDHCP = false;

    firewall = {
      enable = true;
      allowedTCPPorts = [
        3000
        3001
        9000
        24212
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
          MTUBytes = 1500;
        };
        bondConfig = {
          Mode = "active-backup";
          MIIMonitorSec = "0.05";
          PrimaryReselectPolicy = "better";
          UpDelaySec = 0;
          DownDelaySec = 0;
        };
      };
    };

    networks = {
      "30-eno1" = {
        matchConfig.Name = "eno1";
        networkConfig = {
          Bond = "bond0";
          PrimarySlave = true; 
        };
        linkConfig = {
          MTUBytes = 1500;
        };
      };

      "30-enp4s0" = {
        matchConfig.Name = "enp4s0";
        networkConfig.Bond = "bond0";
        linkConfig = {
          MTUBytes = 1500;
        };
      };

      "40-bond0" = {
        matchConfig.Name = "bond0";
        linkConfig.RequiredForOnline = "carrier";
        networkConfig.DHCP = "yes";
        linkConfig = {
          MTUBytes = 1500;
        };
      };
    };
  };
}
