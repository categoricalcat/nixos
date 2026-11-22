{ addresses, lib, ... }:

let
  resolvFallbackNameservers = map (
    server: lib.removeSuffix "]" (lib.removePrefix "[" (lib.removeSuffix ":53" server))
  ) addresses.dns.fallbackServers;
in
{
  # Interface roles, VLANs, and DHCP ranges live in modules/addresses/hosts.nix.

  imports = [
    ./networking/dhcp.nix
    ./networking/wans.nix
    ./networking/bridge.nix
    ./networking/sysctl.nix
    ./networking/firewall.nix
    ./networking/untrusted.nix
    ../../modules/networking/sinkhole.nix
    ../../packages/gateway-failover
  ];

  networking = {
    nameservers = addresses.dns.systemNameservers ++ lib.take 2 resolvFallbackNameservers;

    networkmanager.enable = false;
    useNetworkd = true;
    useDHCP = false;
  };

  systemd.network = {
    enable = true;
    wait-online = {
      anyInterface = false;
      timeout = 15;
    };
  };
}
