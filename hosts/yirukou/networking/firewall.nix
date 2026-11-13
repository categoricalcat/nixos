{
  addresses,
  allAddresses,
  config,
  lib,
  ...
}:

# Packet policy layers, earliest first:
#   raw (-300)      yirukou-edge prerouting (bogon / WAN IPv6)
#   mangle + 10     nixos-fw rpfilter
#   dstnat (-100)   yirukou-dns (plain DNS redirect)
#   filter - 10     yirukou-edge input/forward denies
#   filter - 1      sinkhole
#   filter (0)      nixos-fw input/forward accepts then drop
#   srcnat (100)    yirukou-nat (WAN masquerade, tailnet-to-nginx input SNAT)
#
# yirukou-edge may only drop before nixos-fw. Accepts belong in
# networking.firewall, since nixos-fw is policy drop.
let
  inherit (addresses.network) lan untrusted wan;
  vpn = addresses.network.vpn.interface;
  internalInterfaces = [
    lan.interface
    untrusted.interface
    vpn
  ];
  wanInterfaces = [
    wan.primary.interface
    wan.fallback.interface
  ];
  nginxTcpPorts = [
    config.services.nginx.defaultHTTPListenPort
    config.services.nginx.defaultSSLListenPort
  ];
  lanTcpPorts = [
    53
  ]
  ++ nginxTcpPorts
  ++ [
    853
    3443 # AGH DoH (DDR advertises port_https, not nginx 443)
  ];
  untrustedTcpPorts = [
    53
    853
    3443 # AGH DoH (DDR advertises port_https, not nginx 443)
  ];
  internalUdpPorts = [
    53
    67 # DHCPv4
    853
  ];
  quote = v: ''"${v}"'';
  join = vs: lib.concatStringsSep ", " vs;
  ifaces = vs: join (map quote vs);
  wanIfaceSet = ifaces wanInterfaces;
  internalIfaceSet = ifaces internalInterfaces;
  wanBogonV4 = join [
    "0.0.0.0/8"
    "10.0.0.0/8"
    "100.64.0.0/10"
    "127.0.0.0/8"
    "169.254.0.0/16"
    "172.16.0.0/12"
    "192.0.0.0/24"
    "192.0.2.0/24"
    "192.168.0.0/16"
    "198.18.0.0/15"
    "198.51.100.0/24"
    "203.0.113.0/24"
    "224.0.0.0/4"
    "240.0.0.0/4"
  ];
  yifuwuqi = allAddresses.hosts.yifuwuqi.network;
  magicDns = allAddresses.tailscale.magicDns;
  publicDnsV4 = join allAddresses.publicDnsResolvers.ipv4;
  ourDnsV4 = join [
    lan.ipv4.host
    untrusted.ipv4.host
    addresses.network.vpn.ipv4.host
  ];
  ourDnsV6 = join [
    lan.ipv6.host
    untrusted.ipv6.host
  ];
  ifaceSets = ''
    set wan_ifaces {
      type ifname
      elements = { ${wanIfaceSet} }
    }
    set internal_ifaces {
      type ifname
      elements = { ${internalIfaceSet} }
    }
    set dns_client_ifaces {
      type ifname
      elements = { ${internalIfaceSet} }
    }
  '';
in
{
  networking = {
    firewall = {
      filterForward = true;
      allowPing = false;
      # yi.tailscale maps routingMode=both to useRoutingFeatures=server,
      # which does not set checkReversePath. Loose RPF is required for WAN
      # failover and Tailscale.
      checkReversePath = "loose";
      interfaces = {
        ${lan.interface} = {
          allowedTCPPorts = lanTcpPorts ++ [ addresses.ssh.listenPort ];
          allowedUDPPorts = internalUdpPorts;
        };
        ${untrusted.interface} = {
          allowedTCPPorts = untrustedTcpPorts;
          allowedUDPPorts = internalUdpPorts;
        };
        # Tailnet clients use this host's DNS and nginx (SNAT'd to the LAN
        # identity for the latter), so tailscale0 mirrors br0's port set.
        ${vpn} = {
          allowedTCPPorts = lanTcpPorts ++ [ addresses.ssh.listenPort ];
          allowedUDPPorts = internalUdpPorts;
        };
        ${wan.primary.interface} = {
          allowedUDPPorts = [ 51820 ];
        };
        ${wan.fallback.interface} = {
          allowedUDPPorts = [ 51820 ];
        };
      };
      extraInputRules = ''
        iifname @internal_ifaces ip protocol icmp accept comment "internal icmp"
        iifname @wan_ifaces ip protocol icmp icmp type echo-request limit rate 5/second accept comment "rate-limited wan ping"
      '';
      extraForwardRules = ''
        iifname @internal_ifaces oifname @wan_ifaces meta nfproto ipv4 accept comment "internal ipv4 to wan"
        iifname "${vpn}" oifname "${lan.interface}" ip daddr ${lan.ipv4.cidr} accept comment "tailscale to lan subnet"
      '';
    };

    nftables = {
      enable = true;
      tables = {
        "nixos-fw".content = lib.mkBefore ifaceSets;

        yirukou-edge = {
          family = "inet";
          content = ''
            ${ifaceSets}
            set wan_bogon_v4 {
              type ipv4_addr
              flags interval
              elements = { ${wanBogonV4} }
            }
            set public_dns_v4 {
              type ipv4_addr
              elements = { ${publicDnsV4} }
            }
            chain wan_bogon {
              ip saddr @wan_bogon_v4 drop comment "spoofed ipv4 on wan"
            }

            chain prerouting {
              type filter hook prerouting priority raw; policy accept;

              iifname @wan_ifaces meta nfproto ipv6 drop comment "disable ipv6 on wan"
              iifname @wan_ifaces jump wan_bogon
            }

            chain input {
              type filter hook input priority filter - 10; policy accept;

              iifname @wan_ifaces meta nfproto ipv6 drop comment "disable ipv6 input on wan"
            }

            chain output {
              type filter hook output priority filter - 10; policy accept;

              oifname @wan_ifaces meta nfproto ipv6 drop comment "disable ipv6 output on wan"
            }

            chain forward {
              type filter hook forward priority filter - 10; policy accept;

              iifname @dns_client_ifaces oifname @wan_ifaces meta l4proto tcp th dport 853 reject with tcp reset comment "no off-net DoT"
              iifname @dns_client_ifaces oifname @wan_ifaces meta l4proto udp th dport 853 reject with icmpx type port-unreachable comment "no off-net DoQ"
              iifname @dns_client_ifaces oifname @wan_ifaces ip daddr @public_dns_v4 meta l4proto tcp th dport 443 reject with tcp reset comment "no off-net DoH"
              iifname @dns_client_ifaces oifname @wan_ifaces ip daddr @public_dns_v4 meta l4proto udp th dport 443 reject with icmpx type port-unreachable comment "no off-net DoH3"
              iifname @wan_ifaces meta nfproto ipv6 drop comment "disable inbound ipv6 forwarding on wan"
              oifname @wan_ifaces meta nfproto ipv6 drop comment "disable outbound ipv6 forwarding on wan"
              iifname "${untrusted.interface}" oifname "${lan.interface}" drop comment "isolate untrusted from lan"
              iifname "${lan.interface}" oifname "${untrusted.interface}" drop comment "isolate lan from untrusted"
            }
          '';
        };

        yirukou-dns = {
          family = "inet";
          content = ''
            ${ifaceSets}
            set our_dns_v4 {
              type ipv4_addr
              elements = { ${ourDnsV4} }
            }
            set our_dns_v6 {
              type ipv6_addr
              elements = { ${ourDnsV6} }
            }

            chain prerouting {
              type nat hook prerouting priority dstnat; policy accept;

              iifname @dns_client_ifaces meta l4proto { tcp, udp } th dport 53 ip daddr ${magicDns.ipv4} return
              iifname @dns_client_ifaces meta l4proto { tcp, udp } th dport 53 ip6 daddr ${magicDns.ipv6} return
              iifname @dns_client_ifaces meta l4proto { tcp, udp } th dport 53 ip daddr @our_dns_v4 return
              iifname @dns_client_ifaces meta l4proto { tcp, udp } th dport 53 ip6 daddr @our_dns_v6 return
              iifname { "${lan.interface}", "${vpn}" } meta l4proto { tcp, udp } th dport 53 ip daddr { ${yifuwuqi.lan.ipv4.host}, ${yifuwuqi.vpn.ipv4.host} } return
              iifname { "${lan.interface}", "${vpn}" } meta l4proto { tcp, udp } th dport 53 ip6 daddr ${yifuwuqi.lan.ipv6.host} return
              iifname "${lan.interface}" meta l4proto { tcp, udp } th dport 53 dnat ip to ${lan.ipv4.host}:53
              iifname "${lan.interface}" meta l4proto { tcp, udp } th dport 53 dnat ip6 to [${lan.ipv6.host}]:53
              iifname "${untrusted.interface}" meta l4proto { tcp, udp } th dport 53 dnat ip to ${untrusted.ipv4.host}:53
              iifname "${untrusted.interface}" meta l4proto { tcp, udp } th dport 53 dnat ip6 to [${untrusted.ipv6.host}]:53
              iifname "${vpn}" meta l4proto { tcp, udp } th dport 53 dnat ip to ${addresses.network.vpn.ipv4.host}:53
              iifname "${vpn}" meta l4proto { tcp, udp } th dport 53 dnat ip6 to [${lan.ipv6.host}]:53
            }
          '';
        };

        # Tailscale masquerades only forwarded subnet-route traffic, so
        # connections ending on this host keep their tailnet source; the input
        # chain gives them nginx's LAN identity.
        yirukou-nat = {
          family = "ip";
          content = ''
            ${ifaceSets}
            chain post {
              type nat hook postrouting priority srcnat; policy accept;

              iifname @internal_ifaces oifname @wan_ifaces masquerade
            }

            chain input {
              type nat hook input priority srcnat; policy accept;

              iifname "${vpn}" ip daddr ${lan.ipv4.host} tcp dport { ${join (map toString nginxTcpPorts)} } snat to ${lan.ipv4.host} comment "tailnet subnet route reaches nginx as lan"
            }
          '';
        };
      };
    };
  };
}
