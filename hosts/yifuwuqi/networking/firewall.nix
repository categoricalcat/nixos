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
  publicDnsV4 = nftSet allAddresses.publicDnsResolvers.ipv4;
  wanInterfaces = nftSet (
    map (interface: "\"${interface}\"") [
      addresses.network.lan.interface
      addresses.network.secondary.interface
    ]
  );
  cloudflaredSource = addresses.containers.cloudflared.network.ipv4.host;

  # The gateway reaches only the local ingress (which fronts every proxied
  # backend) and Loki's push port.
  gatewayPorts = map toString [
    addresses.services.ingress.port
    addresses.services.loki.port
  ];
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
      # systemd-resolved stub (bound to 100.69.0.6), everything else via the subnet route.
      interfaces.${addresses.network.tailscale.interface} = {
        allowedTCPPorts = [
          addresses.ssh.listenPort
          addresses.dns.port
        ];
        allowedUDPPorts = [ addresses.dns.port ];
      };

      interfaces."eno1" = {
        allowedTCPPorts = [
          addresses.ssh.listenPort
          addresses.dns.port
          139 # Samba NetBIOS Session
          445 # Samba SMB
          3000 # workd dev server
          6006 # workd dev server
        ];

        allowedUDPPorts = [
          addresses.dns.port
          137 # NetBIOS Name Service
          138 # NetBIOS Datagram Service
        ];
      };

      extraInputRules = ''
        # The gateway (and SNAT'd tailnet clients arriving with its address)
        # reaches only the local ingress and Loki push. A SNAT'd source is
        # a routing fact, not an identity; mTLS Tier 2 authenticates the hop.
        iifname "eno1" ip saddr ${allAddresses.hosts.yirukou.network.lan.ipv4.host} tcp dport { ${lib.concatStringsSep ", " gatewayPorts} } accept comment "allow yirukou gateway to local ingress and loki push"

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
        ip saddr { ${containerSourceSubnets} } meta l4proto tcp th dport 853 reject with tcp reset comment "no container off-net DoT"
        ip saddr { ${containerSourceSubnets} } meta l4proto udp th dport 853 reject with icmpx type port-unreachable comment "no container off-net DoQ"
        ip saddr { ${containerSourceSubnets} } ip daddr { ${publicDnsV4} } meta l4proto tcp th dport 443 reject with tcp reset comment "no container off-net DoH"
        ip saddr { ${containerSourceSubnets} } ip daddr { ${publicDnsV4} } meta l4proto udp th dport 443 reject with icmpx type port-unreachable comment "no container off-net DoH3"
        ip saddr { ${containerSourceSubnets} } oifname { ${wanInterfaces} } accept comment "allow container wan egress"

        iifname "${addresses.network.tailscale.interface}" oifname "${addresses.network.secondary.interface}" ip daddr ${addresses.network.secondary.ipv4.gatewayRoute} accept comment "allow tailscale fallback gateway"
      '';
    };

    nftables = {
      enable = true;
      tables.yifuwuqi-dns = {
        family = "inet";
        content = ''
          chain prerouting {
            type nat hook prerouting priority dstnat; policy accept;

            ip saddr { ${containerSourceSubnets} } fib daddr type != local meta l4proto { tcp, udp } th dport 53 dnat ip to ${addresses.network.lan.ipv4.host}:53
          }
        '';
      };
    };

  };
}
