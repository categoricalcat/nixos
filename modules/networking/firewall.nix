_:

{
  networking = {
    firewall = {
      enable = true;
      allowPing = true;
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
        9090 # Cockpit
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
        "bond0"
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
              
              # MSS clamping for bond0 (MTU 1492 - 40 = 1452)
              tcp flags syn tcp option maxseg size set 1452 oifname "bond0"
              tcp flags syn tcp option maxseg size set 1452 iifname "bond0"
              
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
              iifname { "bond0", "wg0" } tcp dport 3333 accept
              
              # Drop all other attempts to access port 3333
              tcp dport 3333 drop
            }
          '';
        };

      };
    };

    nat = {
      enable = true;
      externalInterface = "bond0";
      internalInterfaces = [ "wg0" ];
    };
  };
}
