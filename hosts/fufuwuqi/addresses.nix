{ wireguardPeers, ... }:
{
  _module.args.addresses = {
    hostName = "fufuwuqi";

    dns = {
      systemNameservers = [
        "::1"
        "127.0.0.1"
      ];
      opendns = [
        "https://doh.opendns.com/dns-query"
        "208.67.222.222"
        "208.67.220.220"
      ];
      nextdns = [
        "ecfc5e.dns.nextdns.io"
        "https://dns.nextdns.io/ecfc5e"
        "45.90.28.0"
        "45.90.30.0"
        "2a07:a8c0::ec:fc5e"
        "2a07:a8c1::ec:fc5e"
      ];
      freedns = [
        "p0.freedns.controld.com"
        "https://freedns.controld.com/p0"
        "2606:1a40:1::"
        "2606:1a40::"
        "76.76.10.0"
        "76.76.2.0"
      ];
      quad9 = [
        "dns.quad9.net"
        "https://dns.quad9.net/dns-query"
        "2620:fe::fe"
        "2620:fe::9"
        "9.9.9.9"
        "149.112.112.112"

      ];
      google = [
        "dns.google.com"
        "https://dns.google/dns-query"
        "2001:4860:4860::8888"
        "2001:4860:4860::8844"
        "8.8.8.8"
        "8.8.4.4"
      ];
      cloudflare = [
        "1dot1dot1dot1.cloudflare-dns.com"
        "https://cloudflare-dns.com/dns-query"
        "2606:4700:4700::1111"
        "2606:4700:4700::1001"
        "1.1.1.1"
        "1.0.0.1"
      ];
      adguard = [
        "dns.adguard-dns.com"
        "https://dns.adguard-dns.com/dns-query"
        "94.140.14.14"
      ];
      domain = "vpn";
    };

    network = {
      vpn = {
        interface = "wg0";
        ipv6 = rec {
          host = "fd00:100::1"; # Using ULA for VPN
          prefixLength = 64;
          address = "${host}/${builtins.toString prefixLength}";
        };
        ipv4 = rec {
          host = "10.100.0.1";
          prefixLength = 24;
          address = "${host}/${builtins.toString prefixLength}";
        };
        peers = wireguardPeers.peerConfigs;
      };

      lan = {
        interface = "bond0";
        # ipv6 = rec {
        #   host = "2804:41fc:8030:ace0::40";
        #   prefixLength = 64;
        #   address = "${host}/${builtins.toString prefixLength}";
        #   gateway = "fe80::1";
        # };
        ipv4 = rec {
          host = "192.168.1.42";
          prefixLength = 24;
          address = "${host}/${builtins.toString prefixLength}";
          gateway = "192.168.1.1";
        };
      };
    };

    wireguard = {
      listenPort = 51820;
    };

    ssh = {
      listenPort = 24212;
      listenAddresses = [
        "192.168.1.42"
        "10.100.0.1"
      ];
      listenWildcardIPv6 = "[::]";
    };

    containers = {
      subnetPools = [
        {
          base = "172.17.0.0/16";
          size = 24;
        }
        {
          base = "172.18.0.0/16";
          size = 24;
        }
      ];
    };
  };
}
