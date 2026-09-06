{
  addresses,
  allAddresses,
  lib,
  ...
}:

# Packet policy layers, earliest first:
#   raw (-300)      yirukou-edge prerouting (bogon / fallback-WAN IPv6)
#   mangle + 10     nixos-fw rpfilter
#   dstnat (-100)   yirukou-dns (plain DNS redirect)
#   filter - 10     yirukou-edge input/forward denies
#   filter - 1      sinkhole
#   filter (0)      nixos-fw input/forward accepts then drop
#   srcnat (100)    yirukou-nat
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
  internalTcpPorts = [
    53
    80
    443
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
  wanBogonV6 = join [
    "::/128"
    "::1/128"
    "64:ff9b::/96"
    "100::/64"
    "2001:2::/48"
    "2001:10::/28"
    "2001:db8::/32"
    "2002::/16"
    "fc00::/7"
    "fe80::/10"
    "ff00::/8"
  ];
  yifuwuqi = allAddresses.hosts.yifuwuqi.network;
  magicDns = allAddresses.tailscale.magicDns;
  ourDnsV4 = join [
    lan.ipv4.host
    untrusted.ipv4.host
    addresses.network.vpn.ipv4.host
    yifuwuqi.lan.ipv4.host
    yifuwuqi.vpn.ipv4.host
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
          allowedTCPPorts = internalTcpPorts ++ [ addresses.ssh.listenPort ];
          allowedUDPPorts = internalUdpPorts;
        };
        ${untrusted.interface} = {
          allowedTCPPorts = internalTcpPorts;
          allowedUDPPorts = internalUdpPorts;
        };
        ${vpn} = {
          allowedTCPPorts = [ addresses.ssh.listenPort ];
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
        iifname @internal_ifaces oifname "${wan.primary.interface}" meta nfproto ipv6 accept comment "internal ipv6 to primary wan"
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
            set wan_bogon_v6 {
              type ipv6_addr
              flags interval
              elements = { ${wanBogonV6} }
            }

            chain wan_ll_ok {
              ip6 saddr fe80::/10 icmpv6 type {
                destination-unreachable,
                packet-too-big,
                time-exceeded,
                parameter-problem,
                nd-router-advert,
                nd-neighbor-solicit,
                nd-neighbor-advert
              } accept comment "essential primary wan icmpv6"
              ip6 saddr fe80::/10 udp sport 547 udp dport 546 accept comment "primary wan dhcpv6"
            }

            chain wan_bogon {
              ip saddr @wan_bogon_v4 drop comment "spoofed ipv4 on wan"
              ip6 saddr @wan_bogon_v6 drop comment "spoofed ipv6 on wan"
            }

            chain prerouting {
              type filter hook prerouting priority raw; policy accept;

              iifname "${wan.fallback.interface}" meta nfproto ipv6 drop comment "disable ipv6 on fallback wan"
              iifname "${wan.primary.interface}" jump wan_ll_ok
              iifname @wan_ifaces jump wan_bogon
            }

            chain input {
              type filter hook input priority filter - 10; policy accept;

              iifname @wan_ifaces icmpv6 type echo-request limit rate over 5/second drop comment "rate-limit wan ping6"
            }

            chain forward {
              type filter hook forward priority filter - 10; policy accept;

              iifname @dns_client_ifaces oifname @wan_ifaces meta l4proto { tcp, udp } th dport 853 drop comment "no off-net DoT/DoQ"
              oifname "${wan.fallback.interface}" meta nfproto ipv6 drop comment "disable ipv6 forwarding through fallback wan"
              iifname @wan_ifaces oifname @internal_ifaces meta nfproto ipv6 ct state { invalid, new, untracked } drop comment "drop unsolicited inbound ipv6"
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

            chain prerouting {
              type nat hook prerouting priority dstnat; policy accept;

              iifname @dns_client_ifaces meta l4proto { tcp, udp } th dport 53 ip daddr ${magicDns.ipv4} return
              iifname @dns_client_ifaces meta l4proto { tcp, udp } th dport 53 ip6 daddr ${magicDns.ipv6} return
              iifname @dns_client_ifaces meta l4proto { tcp, udp } th dport 53 ip daddr @our_dns_v4 return
              iifname @dns_client_ifaces meta l4proto { tcp, udp } th dport 53 fib daddr type local return
              iifname @dns_client_ifaces ip saddr ${yifuwuqi.lan.ipv4.host} meta l4proto { tcp, udp } th dport 53 return
              iifname "${lan.interface}" ip6 saddr & ::ffff:ffff:ffff:ffff == ${yifuwuqi.lan.ipv6.interfaceId} meta l4proto { tcp, udp } th dport 53 return
              iifname @dns_client_ifaces meta l4proto { tcp, udp } th dport 53 redirect to :53
            }
          '';
        };

        yirukou-nat = {
          family = "ip";
          content = ''
            ${ifaceSets}
            chain post {
              type nat hook postrouting priority srcnat; policy accept;

              iifname @internal_ifaces oifname @wan_ifaces masquerade
            }
          '';
        };
      };
    };
  };
}
