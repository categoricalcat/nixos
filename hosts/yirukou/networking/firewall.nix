{
  addresses,
  config,
  lib,
  ...
}:

let
  inherit (addresses.network) lan untrusted wan;
  internalInterfaces = [
    lan.interface
    untrusted.interface
    # config.services.tailscale.interfaceName
    addresses.network.vpn.interface
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
  ];
  internalUdpPorts = [
    53
    67 # DHCPv4
    853
  ];
  nftStringSet = values: lib.concatStringsSep ", " (map (value: ''"${value}"'') values);
  nftAddressSet = values: lib.concatStringsSep ", " values;
  internalSet = nftStringSet internalInterfaces;
  wanSet = nftStringSet wanInterfaces;
  wanBogonV4Set = nftAddressSet [
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
  wanBogonV6Set = nftAddressSet [
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
in
{
  networking = {
    firewall = {
      enable = true;
      backend = "nftables";
      filterForward = true;
      allowPing = false;
      interfaces = {
        ${lan.interface} = {
          allowedTCPPorts = internalTcpPorts ++ [ addresses.ssh.listenPort ];
          allowedUDPPorts = internalUdpPorts;
        };
        ${untrusted.interface} = {
          allowedTCPPorts = internalTcpPorts;
          allowedUDPPorts = internalUdpPorts;
        };
        # ${config.services.tailscale.interfaceName} = {
        #   allowedTCPPorts = [ addresses.ssh.listenPort ];
        # };
        ${addresses.network.vpn.interface} = {
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
        iifname { ${wanSet} } ct state invalid drop comment "drop invalid wan input"

        iifname { ${internalSet} } ip protocol icmp accept comment "internal icmp"
        iifname { ${internalSet} } ip6 nexthdr ipv6-icmp accept comment "internal icmpv6"
        iifname { ${wanSet} } ip protocol icmp icmp type echo-request limit rate 5/second accept comment "rate-limited wan ping"
        iifname { ${wanSet} } ip6 nexthdr ipv6-icmp icmpv6 type echo-request limit rate 5/second accept comment "rate-limited wan ping6"
      '';
      extraForwardRules = ''
        iifname { ${wanSet} } ct state invalid drop comment "drop invalid wan forward"
        iifname { ${internalSet} } oifname { ${wanSet} } accept comment "internal to wan"
        # iifname "${config.services.tailscale.interfaceName}" oifname "${lan.interface}" ip daddr ${lan.ipv4.cidr} accept comment "tailscale to lan subnet"
        # iifname "${lan.interface}" oifname "${config.services.tailscale.interfaceName}" ip saddr ${lan.ipv4.cidr} ct state established,related accept comment "lan replies to tailscale subnet clients"

        iifname "${addresses.network.vpn.interface}" oifname "${lan.interface}" ip daddr ${lan.ipv4.cidr} accept comment "tailscale to lan subnet"
        iifname "${lan.interface}" oifname "${addresses.network.vpn.interface}" ip saddr ${lan.ipv4.cidr} ct state established,related accept comment "lan replies to tailscale clients"
      '';
    };

    nftables = {
      enable = true;
      tables = {
        yirukou-edge = {
          family = "inet";
          content = ''
            chain prerouting {
              type filter hook prerouting priority raw; policy accept;

              iifname { ${wanSet} } ip saddr { ${wanBogonV4Set} } drop comment "drop spoofed ipv4 sources on wan"
              iifname { ${wanSet} } ip6 saddr { ${wanBogonV6Set} } drop comment "drop spoofed ipv6 sources on wan"
            }
          '';
        };

        yirukou-nat = {
          family = "ip";
          content = ''
            chain post {
              type nat hook postrouting priority srcnat; policy accept;

              iifname { ${internalSet} } oifname { ${wanSet} } masquerade
            }
          '';
        };
      };
    };
  };
}
