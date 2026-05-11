_:

{
  systemd.network = {
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
    };
  };
}
