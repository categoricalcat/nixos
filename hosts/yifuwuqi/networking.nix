{ addresses, ... }:
{
  imports = [
    ../../modules/networking/firewall.nix
    ../../modules/networking/interfaces/bond0.nix
    ../../modules/networking/interfaces/wg0.nix
    ../../modules/networking/interfaces/wlp2s0.nix
    ../../modules/networking/tweaks.nix
  ];

  services.resolved = {
    enable = false;
  };

  networking = {
    inherit (addresses) hostName;

    nameservers = addresses.dns.systemNameservers;

    networkmanager.enable = false;
    useNetworkd = true;
    useDHCP = false;
  };

  systemd.network = {
    enable = true;
    wait-online.enable = true;
  };

}
