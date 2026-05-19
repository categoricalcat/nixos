{
  addresses,
  allAddresses,
  lib,
  ...
}:

let
  nftSet = values: lib.concatStringsSep ", " values;
  containerSourceSubnets = nftSet addresses.containers.isolation.sourceSubnets;
  privateDestinationSubnets = nftSet addresses.containers.isolation.blockedDestinationSubnets;
  trustedHostDestinations = nftSet [
    addresses.network.zerotier.ipv4.host
    addresses.network.lan.ipv4.host
    allAddresses.hosts.yirukou.network.lan.ipv4.host
  ];
in

{
  networking = {
    firewall = {
      enable = true;
      allowPing = true;
      # Strict rpfilter (the default) drops inbound packets whose source
      # address doesn't pass a FIB reverse-path check on the arriving
      # interface.  Because yifuwuqi routes all traffic through a Tailscale
      # exit node, return traffic arrives on tailscale0 with source IPs that
      # fail strict rpfilter.  "loose" only verifies the source is routable
      # via *any* interface, which is compatible with Tailscale + exit nodes.
      checkReversePath = "loose";
      logReversePathDrops = true;
      logRefusedPackets = true;
      allowedTCPPorts = [ ];
      allowedUDPPorts = [
        5353 # mDNS/Avahi
      ];

      trustedInterfaces = [
        "tailscale0"
        "eno1"
        "enp4s0"
      ];

      interfaces."eno1".allowedTCPPorts = [ addresses.ssh.listenPort ];
      # interfaces."eno1".allowedUDPPorts = [];
    };

    nftables = {
      enable = true;
      tables = {
        # Smarter Container Isolation
        # Allows tunnel containers to talk to the host (e.g., database)
        # but blocks access to the rest of the internal LAN/VPN network.
        container-isolation = {
          family = "inet";
          content = ''
            chain forward {
              type filter hook forward priority 0;

              # Match traffic from the configured Podman/container subnets
              # targeting private IP ranges.

              # 1. Allow containers to talk to the host's LAN/VPN/ZT IPs directly for services (like MariaDB)
              ip saddr { ${containerSourceSubnets} } ip daddr { ${trustedHostDestinations} } accept

              # 2. Block containers from reaching any other internal IP range
              ip saddr { ${containerSourceSubnets} } ip daddr { ${privateDestinationSubnets} } drop
            }
          '';
        };

        # sinkhole table defined in ../../modules/networking/sinkhole.nix
      };
    };

  };
}
