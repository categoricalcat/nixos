{ addresses, lib, ... }:

let
  nftSet = values: lib.concatStringsSep ", " values;
  containerSourceSubnets = nftSet addresses.containers.isolation.sourceSubnets;
  privateDestinationSubnets = nftSet addresses.containers.isolation.blockedDestinationSubnets;
  trustedHostDestinations = nftSet [
    addresses.network.zerotier.ipv4.host
    addresses.network.lan.ipv4.host
  ];
in

{
  networking = {
    firewall = {
      enable = true;
      allowPing = true;
      logReversePathDrops = true;
      logRefusedPackets = true;
      allowedTCPPorts = [
        53 # DNS
        80 # HTTP
        443 # HTTPS / DoH
        853 # DNS-over-TLS
      ];
      allowedUDPPorts = [
        53 # DNS
        853 # DNS-over-QUIC
        5353 # mDNS/Avahi
      ];

      trustedInterfaces = [
        "tailscale0"
        "eno1"
      ];

      interfaces."eno1".allowedTCPPorts = [ 24212 ];
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
