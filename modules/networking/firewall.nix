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
        24212 # SSH
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
        "wg0"
        "tailscale0"
        "eno1"
      ];
    };

    nftables = {
      enable = true;
      tables = {
        mssclamp = {
          family = "inet";
          content = ''
            chain forward {
              type filter hook forward priority mangle;

              # MSS clamping for eno1 (MTU 1492 - 40 = 1452)
              tcp flags syn tcp option maxseg size set 1452 oifname "eno1"
              tcp flags syn tcp option maxseg size set 1452 iifname "eno1"

              # MSS clamping for enp4s0 (MTU 1500 - 40 = 1460)
              tcp flags syn tcp option maxseg size set 1460 oifname "enp4s0"
              tcp flags syn tcp option maxseg size set 1460 iifname "enp4s0"

              # MSS clamping for wg0 (MTU 1380 - 40 = 1340)
              tcp flags syn tcp option maxseg size set 1340 oifname "wg0"
              tcp flags syn tcp option maxseg size set 1340 iifname "wg0"
            }
          '';
        };

        # Restrict AdGuard UI access to LAN/VPN only
        adguard-restrict = {
          family = "inet";
          content = ''
            chain input {
              type filter hook input priority 0;

              # Allow AdGuard UI (port 3333) only from LAN and VPN interfaces
              iifname { "eno1", "enp4s0", "wg0" } tcp dport 3333 accept

              # Drop all other attempts to access port 3333
              tcp dport 3333 drop
            }
          '';
        };

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
      };
    };

    nat = {
      enable = false;
      externalInterface = "eno1";
      internalInterfaces = [ "wg0" ];
    };
  };
}
