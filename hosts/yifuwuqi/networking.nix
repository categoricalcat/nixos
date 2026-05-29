{ addresses, ... }:
{
  imports = [
    ./networking/firewall.nix
    ../../modules/networking/sinkhole.nix
    ../../modules/networking/gateway-failover.nix
    ./networking/interfaces/eno1.nix
    ./networking/interfaces/enp4s0.nix
    ./networking/interfaces/wlp2s0.nix
    ./networking/sysctl.nix
  ];

  services.resolved = {
    enable = false;
    extraConfig = "DNSStubListener=no";
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
