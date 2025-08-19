# Networking configuration module

_:

let
  dnsServers = [
    "2001:4860:4860::8888" # Google IPv6 DNS
    "2606:4700:4700::1111" # Cloudflare IPv6 DNS
    # "8.8.8.8" # Google IPv4 DNS (fallback)
    # "1.1.1.1" # Cloudflare IPv4 DNS (fallback)
  ];
in
{
  networking = {
    hostName = "fufuwuqi";

    nameservers = dnsServers;

    # IPv6 configuration - prefer IPv6 over IPv4
    enableIPv6 = true;
    tempAddresses = "enabled"; # Privacy extensions for IPv6

    networkmanager.enable = false;
    useNetworkd = true;
    useDHCP = false;

    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [
        # 80
        # 443
        # 3000
        # 3001
        # 9000
        # 24212
        25565 # Minecraft server
        # 9090 # Cockpit
      ];
      allowedUDPPorts = [
        25565 # Minecraft server
        5353 # mDNS/Avahi
        51820 # WireGuard VPN
      ];

      trustedInterfaces = [ "wg0" ];

      # Allow LAN clients on bond0 to query dnsmasq (TCP/UDP 53)
      interfaces.bond0 = {
        allowedTCPPorts = [ 53 ];
        allowedUDPPorts = [ 53 ];
      };
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

        privateKeyFile = "/etc/wireguard/private.key"; # wg genkey | sudo tee /etc/wireguard/private.key

        peers = [
          {
            publicKey = "e234011QJdJtl67vFF8Dp3wGLixnkRFXtkcDamR1vh8=";
            allowedIPs = [ "10.100.0.2/32" ]; # macos
            persistentKeepalive = 25;
          }
          {

            publicKey = "aDcV7ZGtQTg/0twxpObeU1FM+nBFgD9wlYQ8Txygf3U=";
            allowedIPs = [ "10.100.0.3/32" ]; # windows
            persistentKeepalive = 25;
          }
        ];
      };
    };

    # Ensure the VPN server IP does not resolve to localhost
    # and gives a stable hostname for tools like traceroute
    hosts = {
      "10.100.0.1" = [
        "fufuwuqi.vpn"
        "fufuwuqi"
      ];
    };
  };

  # Systemd network configuration for bonding
  systemd.network = {
    enable = true;
    wait-online.enable = true;

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
      "20-wlp2s0" = {
        matchConfig.Name = "wlp2s0";
        linkConfig = {
          ActivationPolicy = "down";
          RequiredForOnline = "no";
        };
        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = "no";
        };
      };

      "30-eno1" = {
        matchConfig.Name = "eno1";
        networkConfig = {
          Bond = "bond0";
          PrimarySlave = true;
          DNS = dnsServers;
        };
        linkConfig = {
          MTUBytes = 1492;
        };
      };

      "30-enp4s0" = {
        matchConfig.Name = "enp4s0";
        networkConfig = {
          Bond = "bond0";
          DNS = dnsServers;
        };
        linkConfig = {
          MTUBytes = 1492;
        };
      };

      "40-bond0" = {
        matchConfig.Name = "bond0";
        networkConfig = {
          DHCP = "yes";
          DNS = dnsServers;
          IPv6AcceptRA = "yes";
          LinkLocalAddressing = "ipv6";
        };
        linkConfig = {
          MTUBytes = 1492;
          RequiredForOnline = "carrier";
        };

        dhcpV4Config = {
          UseDNS = false;
          RouteMetric = 20;
        };

        ipv6AcceptRAConfig = {
          UseDNS = false;
          RouteMetric = 10;
        };

        dhcpV6Config = {
          UseDNS = false;
          RouteMetric = 10;
        };
      };

      # USB network interfaces (minimal config)
      "50-usb" = {
        matchConfig.Name = "usb* enp*s*u*"; # Match USB network interfaces
        networkConfig = {
          Address = "192.168.100.1/24";
        };
      };
    };
  };

  # Provide a static resolver file so lookups work without systemd-resolved
  # This keeps DNS predictable under systemd-networkd-only setups
  environment.etc."resolv.conf".text = ''
    options edns0
    ${builtins.concatStringsSep "\n    " (map (dns: "nameserver ${dns}") dnsServers)}
  '';

  # Configure address selection to prefer IPv6
  environment.etc."gai.conf".text = ''
    # Prefer IPv6 over IPv4 for address selection
    # See gai.conf(5) for details
    precedence ::1/128       50     # localhost (IPv6)
    precedence ::/0          40     # IPv6 global
    precedence ::ffff:0:0/96 30     # IPv4-mapped IPv6
    precedence 2002::/16     20     # 6to4
    precedence 2001::/32     5      # Teredo
    precedence fc00::/7      3      # ULA
    precedence ::/96         1      # IPv4-compatible IPv6
    precedence ::1/128       50     # localhost
  '';
}
