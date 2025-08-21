{ ... }:

{
  imports = [
    ./bond0.nix
    ./wg0.nix
  ];

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

      "50-usb" = {
        matchConfig.Name = "usb* enp*s*u*";
        networkConfig = {
          Address = "192.168.100.1/24";
        };
      };
    };
  };
}
