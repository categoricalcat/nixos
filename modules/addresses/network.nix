# Global network constants: domains, DNS upstreams, and derived/static
# address sets. Consumed via modules/addresses.nix.
let
  baseDomain = "aset.love";
  legacyDomain = "fufu.land";
  email = "catufuzgu@gmail.com";

  sharedDnsUpstreams = {
    opendns = [
      "https://doh.opendns.com/dns-query"
      "tls://dns.opendns.com"
      "tcp://208.67.222.222"
      "208.67.222.222"
      "208.67.220.220"
      "2620:119:35::35"
      "2620:119:53::53"
    ];
    nextdns = [
      "quic://ecfc5e.dns.nextdns.io"
      "h3://dns.nextdns.io/ecfc5e"
      "https://dns.nextdns.io/ecfc5e"
      "tls://ecfc5e.dns.nextdns.io"
      "tcp://45.90.28.0"
      "45.90.28.0"
      "45.90.30.0"
      "2a07:a8c0::ec:fc5e"
      "2a07:a8c1::ec:fc5e"
    ];
    freedns = [
      "quic://p0.freedns.controld.com"
      "h3://freedns.controld.com/p0"
      "https://freedns.controld.com/p0"
      "tls://p0.freedns.controld.com"
      "tcp://76.76.2.0"
      "76.76.2.0"
      "76.76.10.0"
      "2606:1a40::"
      "2606:1a40:1::"
    ];
    quad9 = [
      "quic://dns.quad9.net"
      "h3://dns.quad9.net/dns-query"
      "https://dns.quad9.net/dns-query"
      "tls://dns.quad9.net"
      "tcp://9.9.9.9"
      "9.9.9.9"
      "149.112.112.112"
      "2620:fe::fe"
      "2620:fe::9"
    ];
    google = [
      "https://dns.google/dns-query"
      "tls://dns.google"
      "tcp://8.8.8.8"
      "8.8.8.8"
      "8.8.4.4"
      "2001:4860:4860::8888"
      "2001:4860:4860::8844"
    ];
    cloudflare = [
      "https://cloudflare-dns.com/dns-query"
      "tls://1dot1dot1dot1.cloudflare-dns.com"
      "tcp://1.1.1.1"
      "1.1.1.1"
      "1.0.0.1"
      "2606:4700:4700::1111"
      "2606:4700:4700::1001"
    ];
    adguard = [
      "quic://dns.adguard-dns.com"
      "https://dns.adguard-dns.com/dns-query"
      "tls://dns.adguard-dns.com"
      "tcp://94.140.14.14"
      "94.140.14.14"
      "94.140.15.15"
      "2a10:50c0::ad1:ff"
      "2a10:50c0::ad2:ff"
    ];
  };
in
{
  inherit
    baseDomain
    legacyDomain
    email
    sharedDnsUpstreams
    ;

  tailscale.magicDns = {
    ipv4 = "100.100.100.100";
    ipv6 = "fd7a:115c:a1e0::53";
  };

  publicDnsResolvers = {
    ipv4 =
      builtins.filter (entry: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+" entry != null) (
        builtins.concatLists (builtins.attrValues sharedDnsUpstreams)
      )
      ++ [
        "1.1.1.2"
        "1.0.0.2"
        "1.1.1.3"
        "1.0.0.3"
        "9.9.9.10"
        "9.9.9.11"
        "149.112.112.10"
        "149.112.112.11"
        "185.228.168.9"
        "185.228.169.9"
        "185.228.168.168"
        "194.242.2.2"
        "194.242.2.3"
      ];
  };

  privateDestinations = {
    ipv4 = [
      "127.0.0.0/8"
      "10.0.0.0/8"
      "100.64.0.0/10"
      "169.254.0.0/16"
      "172.16.0.0/12"
      "192.168.0.0/16"
    ];
    ipv6 = [
      "::1/128"
      "fc00::/7"
      "fe80::/10"
    ];
  };
}
