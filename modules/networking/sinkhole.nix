{ addresses, lib, ... }:

let
  ipv4 = addresses.network.sinkhole.ipv4.host;
  ipv6 = addresses.network.sinkhole.ipv6.host;
in
{
  networking.nftables = {
    enable = lib.mkDefault true;

    tables.sinkhole = {
      family = "inet";
      content = ''
        chain input {
          type filter hook input priority -1; policy accept;

          # IPv4 Sinkhole
          ip daddr ${ipv4} meta l4proto tcp counter reject with tcp reset
          ip daddr ${ipv4} counter reject with icmp type host-unreachable

          # IPv6 Sinkhole
          ip6 daddr ${ipv6} meta l4proto tcp counter reject with tcp reset
          ip6 daddr ${ipv6} counter reject with icmpv6 type addr-unreachable
        }

        chain forward {
          type filter hook forward priority -1; policy accept;

          # IPv4 Sinkhole
          ip daddr ${ipv4} meta l4proto tcp counter reject with tcp reset
          ip daddr ${ipv4} counter reject with icmp type host-unreachable

          # IPv6 Sinkhole
          ip6 daddr ${ipv6} meta l4proto tcp counter reject with tcp reset
          ip6 daddr ${ipv6} counter reject with icmpv6 type addr-unreachable
        }

        chain output {
          type filter hook output priority -1; policy accept;

          # IPv4 Sinkhole
          ip daddr ${ipv4} meta l4proto tcp counter reject with tcp reset
          ip daddr ${ipv4} counter reject with icmp type host-unreachable

          # IPv6 Sinkhole
          ip6 daddr ${ipv6} meta l4proto tcp counter reject with tcp reset
          ip6 daddr ${ipv6} counter reject with icmpv6 type addr-unreachable
        }
      '';
    };
  };
}
