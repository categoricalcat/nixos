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
        80
        443
        # 3000
        # 3001
        # 9000
        # 24212
        5353 # mDNS/Avahi
        25565 # Minecraft server
        # 9090 # Cockpit
      ];
      allowedUDPPorts = [
        25565 # Minecraft server
        5353 # mDNS/Avahi
        51820 # WireGuard VPN
      ];

      trustedInterfaces = [ "wg0" ];
    };

    nat = {
      enable = true;
      externalInterface = "bond0";
      internalInterfaces = [ "wg0" ];
    };

    wireguard.interfaces = {
      wg0 = {
        ips = [ "10.100.0.1/28" ];
        listenPort = 51820;
        mtu = 1492;

        # wg genkey | sudo tee /etc/wireguard/private.key
        privateKeyFile = "/etc/wireguard/private.key";

        peers = [
          {
            # macos
            publicKey = "e234011QJdJtl67vFF8Dp3wGLixnkRFXtkcDamR1vh8=";
            allowedIPs = [ "10.100.0.2/32" ];
            persistentKeepalive = 25;
          }
        ];
      };
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
          MTUBytes = 1492;
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
          MTUBytes = 1492;
        };
      };

      "30-enp4s0" = {
        matchConfig.Name = "enp4s0";
        networkConfig.Bond = "bond0";
        linkConfig = {
          MTUBytes = 1492;
        };
      };

      "40-bond0" = {
        matchConfig.Name = "bond0";
        networkConfig.DHCP = "yes";
        linkConfig = {
          MTUBytes = 1492;
          RequiredForOnline = "carrier";
        };
      };

      # USB network interfaces (minimal config)
      "50-usb" = {
        matchConfig.Name = "usb* enp*s*u*"; # Match USB network interfaces
        networkConfig = {
          DHCP = "yes";
          LinkLocalAddressing = "ipv4"; # Fallback for direct connections
        };
      };
    };
  };
}
