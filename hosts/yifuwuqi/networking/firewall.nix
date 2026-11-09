{
  addresses,
  allAddresses,
  lib,
  ...
}:

let
  nftSet = values: lib.concatStringsSep ", " values;
  containerSourceSubnets = nftSet addresses.containers.isolation.sourceSubnets;
  applicationContainerSourceSubnets = nftSet addresses.containers.isolation.applicationSourceSubnets;
  privateDestinationSubnets = nftSet allAddresses.privateDestinations.ipv4;
  wanInterfaces = nftSet (
    map (interface: "\"${interface}\"") [
      addresses.network.lan.interface
      addresses.network.secondary.interface
    ]
  );
  cloudflaredSource = addresses.containers.cloudflared.network.ipv4.host;
in

{
  networking = {
    firewall = {
      enable = true;
      allowPing = true;
      # Gateway failover can make a valid return path differ from ingress.
      checkReversePath = "loose";
      logReversePathDrops = true;
      logRefusedPackets = true;
      filterForward = true;
      allowedTCPPorts = [ ];
      allowedUDPPorts = [
        5353 # mDNS/Avahi
      ];

      # eno1 (LAN) is default-deny. Only explicitly declared ports and yirukou gateway traffic are permitted.
      # tailscale0 is untrusted: the tailnet reaches this host's SSH and its
      # AdGuard DNS (bound to 100.69.0.6), everything else via the subnet route.
      interfaces.${addresses.network.tailscale.interface} = {
        allowedTCPPorts = [
          addresses.ssh.listenPort
          addresses.services.adguardhome.dnsPort
        ];
        allowedUDPPorts = [ addresses.services.adguardhome.dnsPort ];
      };

      interfaces."eno1" = {
        allowedTCPPorts = [
          addresses.ssh.listenPort
          addresses.services.adguardhome.port
          addresses.services.adguardhome.dnsPort
          139 # Samba NetBIOS Session
          445 # Samba SMB
        ];

        allowedUDPPorts = [
          addresses.services.adguardhome.dnsPort
          137 # NetBIOS Name Service
          138 # NetBIOS Datagram Service
        ];
      };

      extraInputRules = ''
        # Allow yirukou reverse proxy and DNS resolver to access backend services
        ip saddr ${allAddresses.hosts.yirukou.network.lan.ipv4.host} accept comment "allow yirukou gateway"

        ip saddr ${cloudflaredSource} tcp dport ${toString addresses.ssh.listenPort} accept comment "allow cloudflared ssh fallback"

        # Container to Host: Principle of Least Privilege
        # 1. Allow containers to reach host DNS (Aardvark-DNS on the bridge gateway; AdGuard Home binds internal IPs only)
        ip saddr { ${containerSourceSubnets} } udp dport 53 accept comment "allow container dns udp"
        ip saddr { ${containerSourceSubnets} } tcp dport 53 accept comment "allow container dns tcp"

        # 2. Exclude Cloudflared from application-container host APIs.
        ip saddr { ${applicationContainerSourceSubnets} } tcp dport {
          ${toString addresses.services.lidarr.port},
          ${toString addresses.services.searxng.port}
        } accept comment "allow containers to specific host apis"
      '';

      extraForwardRules = ''
        # Container forwarding isolation:
        ip saddr { ${containerSourceSubnets} } ip daddr { ${privateDestinationSubnets} } limit rate 5/second burst 10 packets log prefix "container private drop: " level warn
        ip saddr { ${containerSourceSubnets} } ip daddr { ${privateDestinationSubnets} } drop comment "drop container to private networks"
        ip saddr { ${containerSourceSubnets} } oifname { ${wanInterfaces} } accept comment "allow container wan egress"

        iifname "${addresses.network.tailscale.interface}" oifname "${addresses.network.secondary.interface}" ip daddr ${addresses.network.secondary.ipv4.gatewayRoute} accept comment "allow tailscale fallback gateway"
      '';
    };

    nftables = {
      enable = true;
      tables = { };
    };

  };
}
