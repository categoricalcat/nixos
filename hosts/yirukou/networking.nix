{ addresses, lib, ... }:

let
  resolvFallbackNameservers = map (
    server: lib.removeSuffix "]" (lib.removePrefix "[" (lib.removeSuffix ":53" server))
  ) (addresses.dns.fallbackServers or [ ]);
in
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

  services.resolved = {
    enable = false;
    extraConfig = "DNSStubListener=no";
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
