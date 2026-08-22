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
    addresses.network.vpn.ipv4.host
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

      # eno1 (LAN) is default-deny. Only explicitly declared ports and yirukou gateway traffic are permitted.
      trustedInterfaces = [
        "tailscale0"
      ];

      interfaces."eno1" = {
        allowedTCPPorts = [
          addresses.ssh.listenPort
          addresses.services.adguardhome.port
          addresses.services.adguardhome.dnsPort
        ];

        allowedUDPPorts = [
          addresses.services.adguardhome.dnsPort
        ];
      };

      extraInputRules = ''
        # Allow yirukou reverse proxy and DNS resolver to access backend services
        ip saddr ${allAddresses.hosts.yirukou.network.lan.ipv4.host} accept comment "allow yirukou gateway"

        # Allow container subnets to reach host services (e.g. Lidarr API for soularr, MariaDB)
        ip saddr { ${containerSourceSubnets} } accept comment "allow container subnets to host"
      '';

      extraForwardRules = ''
        # Container forwarding isolation:
        # 1. Allow containers to reach host destinations
        ip saddr { ${containerSourceSubnets} } ip daddr { ${trustedHostDestinations} } accept comment "allow containers to host"
        # 2. Block containers from reaching other private subnets
        ip saddr { ${containerSourceSubnets} } ip daddr { ${privateDestinationSubnets} } drop comment "drop container to private networks"
      '';
    };

    nftables = {
      enable = true;
      tables = { };
    };

  };
}
