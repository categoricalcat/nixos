{ addresses, ... }:
{
  imports = [
    ../../modules/networking/firewall.nix
    ../../modules/networking/interfaces/eno1.nix
    ../../modules/networking/interfaces/enp4s0.nix
    ../../modules/networking/gateway-failover.nix
    # ../../modules/networking/interfaces/wg0.nix
    ../../modules/networking/interfaces/wlp2s0.nix
    ../../modules/networking/sysctl.nix
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

    firewall.interfaces."wg0".allowedTCPPorts = [ 9090 ]; # Allow Cockpit via VPN
  };

  systemd.network = {
    enable = true;
    wait-online.enable = true;

    netdevs."20-sinkhole0" = {
      netdevConfig = {
        Kind = "dummy";
        Name = "sinkhole0";
      };
    };

    networks."20-sinkhole0" = {
      matchConfig.Name = "sinkhole0";
      address = [
        "198.51.100.1/32"
        "2001:db8::1/128"
      ];
      networkConfig = {
        ConfigureWithoutCarrier = true;
      };
      linkConfig.RequiredForOnline = "no";
    };
  };

}
