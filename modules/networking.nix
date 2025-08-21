_:

let
  dnsServers = [
    "2001:4860:4860::8888" # Google IPv6 DNS
    "2606:4700:4700::1111" # Cloudflare IPv6 DNS
    "8.8.8.8" # Google IPv4 DNS
    "1.1.1.1" # Cloudflare IPv4 DNS
  ];
in
{
  _module.args.dnsServers = dnsServers;

  services.resolved = {
    enable = true;
    dnsovertls = "opportunistic";
    dnssec = "allow-downgrade";
    fallbackDns = dnsServers;
    llmnr = "false";
    extraConfig = ''
      MulticastDNS=yes
    '';
  };

  networking = {
    hostName = "fufuwuqi";

    nameservers = dnsServers;

    enableIPv6 = true;
    tempAddresses = "enabled";

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

      # Allow VPN clients on wg0 to query dnsmasq
      interfaces.wg0 = {
        allowedTCPPorts = [ 53 ];
        allowedUDPPorts = [ 53 ];
      };
    };

    nat = {
      enable = true;
      externalInterface = "bond0";
      internalInterfaces = [ "wg0" ];
    };

    hosts = {
      "fd00:100::1" = [
        "fufuwuqi.vpn"
        "fufuwuqi"
      ];
      "10.100.0.1" = [
        "fufuwuqi.vpn"
        "fufuwuqi"
      ];
    };
  };

  systemd.network = {
    enable = true;
    wait-online.enable = true;

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
      "30-wg0" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "wg0";
          MTUBytes = 1492;
        };
        wireguardConfig = {
          PrivateKeyFile = "/etc/wireguard/private.key";
          ListenPort = 51820;
        };
        wireguardPeers = [
          {
            PublicKey = "e234011QJdJtl67vFF8Dp3wGLixnkRFXtkcDamR1vh8=";
            AllowedIPs = [
              "fd00:100::2/128"
              "10.100.0.2/32"
            ];
            PersistentKeepalive = 25;
          }
          {
            PublicKey = "aDcV7ZGtQTg/0twxpObeU1FM+nBFgD9wlYQ8Txygf3U=";
            AllowedIPs = [
              "fd00:100::3/128"
              "10.100.0.3/32"
            ];
            PersistentKeepalive = 25;
          }
        ];
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
          DHCP = "no";
          DNS = dnsServers;
          MulticastDNS = "yes";
          IPv6AcceptRA = "no";
          LinkLocalAddressing = "ipv6";

          Address = [
            "2804:41fc:802d:52f0::40/64"
            "192.168.1.40/24"
          ];
        };

        linkConfig = {
          MTUBytes = 1492;
          RequiredForOnline = "carrier";
        };

        routes = [
          {
            Gateway = "fe80::1";
            GatewayOnLink = true;
            Metric = 5;
          }
          {
            Gateway = "192.168.1.1";
            GatewayOnLink = true;
            Metric = 1000;
          }
        ];

      };

      "50-usb" = {
        matchConfig.Name = "usb* enp*s*u*";
        networkConfig = {
          Address = "192.168.100.1/24";
        };
      };

      "60-wg0" = {
        matchConfig.Name = "wg0";
        address = [
          "fd00:100::1/64"
          "10.100.0.1/24"
        ];
        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = "no";
          DNS = [
            "fd00:100::1"
            "10.100.0.1"
          ];
          Domains = [ "~vpn" ];
          DNSDefaultRoute = false;
          MulticastDNS = "yes";
        };
        linkConfig = {
          MTUBytes = 1492;
        };
      };
    };
  };

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
