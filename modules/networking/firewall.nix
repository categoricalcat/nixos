_:

{
  networking = {
    firewall = {
      enable = true;
      allowPing = true;
      logReversePathDrops = true;
      logRefusedPackets = true;
      allowedTCPPorts = [
        53 # DNS
        80 # HTTP
        443 # HTTPS / DoH
        853 # DNS-over-TLS
        # 3333 removed - restricted via nftables rules below
        # 3001
        # 9000
        25565 # Minecraft server
      ];
      allowedUDPPorts = [
        53 # DNS
        853 # DNS-over-QUIC
        25565 # Minecraft server
        5353 # mDNS/Avahi
        51820 # WireGuard VPN
      ];

      trustedInterfaces = [
        # "wg0"
        "tailscale0"
        "eno1"
      ];
    };

    nftables = {
      enable = true;
      tables = {
        # Smarter Container Isolation
        # Allows tunnel containers to talk to the host (e.g., database)
        # but blocks access to the rest of the internal LAN/VPN network.
        container-isolation = {
          family = "inet";
          content = ''
            chain forward {
              type filter hook forward priority 0;

              # Match traffic from the Podman subnets (10.88.x.x default or the 172.x subnets in addresses.nix)
              # targeting private IP ranges.

              # 1. Allow containers to talk to the host's LAN/VPN/ZT IPs directly for services (like MariaDB)
              ip saddr { 10.88.0.0/16, 172.17.0.0/16, 172.18.0.0/16 } ip daddr { 10.100.0.1, 10.0.0.1, 192.168.0.42 } accept

              # 2. Block containers from reaching any other internal IP range
              ip saddr { 10.88.0.0/16, 172.17.0.0/16, 172.18.0.0/16 } ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } drop
            }
          '';
        };

        # for adguardhome
        sinkhole = {
          family = "inet";
          content = ''
            chain input {
              type filter hook input priority filter; policy accept;

              # IPv4 Rejections
              ip daddr 198.51.100.1 counter reject with tcp reset
              ip daddr 198.51.100.1 counter reject with icmp type host-unreachable

              # IPv6 Rejections
              ip6 daddr 2001:db8::1 counter reject with tcp reset
              ip6 daddr 2001:db8::1 counter reject with icmpv6 type addr-unreachable
            }

            chain forward {
              type filter hook forward priority filter; policy accept;

              # IPv4 Rejections
              ip daddr 198.51.100.1 counter reject with tcp reset
              ip daddr 198.51.100.1 counter reject with icmp type host-unreachable

              # IPv6 Rejections
              ip6 daddr 2001:db8::1 counter reject with tcp reset
              ip6 daddr 2001:db8::1 counter reject with icmpv6 type addr-unreachable
            }

            chain output {
              type filter hook output priority filter; policy accept;

              # IPv4 Rejections
              ip daddr 198.51.100.1 counter reject with tcp reset
              ip daddr 198.51.100.1 counter reject with icmp type host-unreachable

              # IPv6 Rejections
              ip6 daddr 2001:db8::1 counter reject with tcp reset
              ip6 daddr 2001:db8::1 counter reject with icmpv6 type addr-unreachable
            }
          '';
        };
      };
    };

    nat = {
      enable = false;
      externalInterface = "eno1";
      internalInterfaces = [ "wg0" ];
    };
  };
}
