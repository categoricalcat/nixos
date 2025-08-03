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
      allowPing = true;
      allowedTCPPorts = [
        3000      # Development servers
        3001      # Development servers
        9000      # Various services
        24212     # SSH custom port
        5353      # mDNS/Avahi
        25565     # Minecraft server
      ];
      allowedUDPPorts = [
        25565     # Minecraft server (UDP is required for Minecraft)
        5353      # mDNS/Avahi
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
        networkConfig.DHCP = "yes";
        linkConfig = {
          MTUBytes = 1500;
          RequiredForOnline = "carrier";
        };
      };

      # USB network interfaces (minimal config)
      "50-usb" = {
        matchConfig.Name = "usb* enp*s*u*";  # Match USB network interfaces
        networkConfig = {
          DHCP = "yes";
          LinkLocalAddressing = "ipv4";  # Fallback for direct connections
        };
      };
    };
  };
}
