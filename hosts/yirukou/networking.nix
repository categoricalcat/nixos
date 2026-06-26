{ addresses, lib, ... }:

let
  resolvFallbackNameservers = map (
    server: lib.removeSuffix "]" (lib.removePrefix "[" (lib.removeSuffix ":53" server))
  ) addresses.dns.fallbackServers;
in
{
  # Interface roles, VLANs, and DHCP ranges live in modules/addresses.nix.

  imports = [
    ./networking/dhcp.nix
    ./networking/wans.nix
    ./networking/bridge.nix
    ./networking/sysctl.nix
    ./networking/firewall.nix
    ./networking/untrusted.nix
    ../../modules/networking/sinkhole.nix
    ../../modules/networking/gateway-failover.nix
  ];

  services.resolved = {
    enable = true;
    settings.Resolve.DNSStubListener = "no";
  };

  networking = {
    inherit (addresses) hostName;
    nameservers = addresses.dns.systemNameservers ++ lib.take 2 resolvFallbackNameservers;

    networkmanager.enable = false;
    useNetworkd = true;
    useDHCP = false;
  };

  systemd.network = {
    enable = true;
    wait-online.anyInterface = true;
  };
}
