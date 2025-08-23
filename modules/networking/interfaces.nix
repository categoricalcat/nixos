{ addresses, ... }:

{
  imports = [
    ./interfaces/bond0.nix
    ./interfaces/wg0.nix
  ];

  systemd.network = {
    networks = {
      "20-wlp2so" = {
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
          Address = addresses.network.usb.address;
        };
      };
    };
  };
}
