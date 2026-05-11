{ addresses, ... }:
{
  # Interface roles, VLANs, and DHCP ranges live in modules/addresses.nix.

  imports = [
    ./networking/wans.nix
    ./networking/bridge.nix
    ./networking/untrusted.nix
    ../../modules/networking/sinkhole.nix
    ../../modules/networking/gateway-failover.nix
    ./networking/firewall.nix
    ./networking/dhcp.nix
  ];

  networking = {
    inherit (addresses) hostName;
    nameservers = addresses.dns.systemNameservers;

    networkmanager.enable = false;
    useNetworkd = true;
    useDHCP = false;
  };

  systemd.network = {
    enable = true;
  };
}
