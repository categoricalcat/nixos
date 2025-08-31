_:

{
  networking = {
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [
        53 # DNS
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
        53 # DNS
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
