_:

{
  networking = {
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [
        80
        443
        3333
        # 3001
        # 9000
        24212
        25565 # Minecraft server
        # 9090 # Cockpit
      ];
      allowedUDPPorts = [
        25565 # Minecraft server
        5353 # mDNS/Avahi
        51820 # WireGuard VPN
      ];

      trustedInterfaces = [
        "wg0"
        "bond0"
      ];

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

    nftables = {
      enable = true;
      tables = {
        mssclamp = {
          family = "inet";
          content = ''
            chain forward {
              type filter hook forward priority mangle;
              tcp flags syn tcp option maxseg size set rt mtu oifname "bond0"
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
