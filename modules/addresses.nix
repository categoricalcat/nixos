{

  hosts = {
    yifuwuqi = rec {
      hostName = "yifuwuqi";

      dns = {
        systemNameservers = [
          "::1"
          "127.0.0.1"
          "9.9.9.9"
        ];
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
        };

        zerotier = {
          interface = "zt0";
          ipv6 = rec {
            host = "fd00::1"; # Using ULA for VPN
            prefixLength = 64;
            address = "${host}/${builtins.toString prefixLength}";
          };
          ipv4 = rec {
            cidr = "10.0.0.0/24";
            host = "10.0.0.1";
            prefixLength = 24;
            address = "${host}/${builtins.toString prefixLength}";
          };
        };

        lan = {
          interface = "eno1";
          ipv4 = rec {
            host = "192.168.0.42";
            prefixLength = 24;
            address = "${host}/${builtins.toString prefixLength}";
            gateway = "192.168.0.1";
          };
        };

        sinkhole = {
          ipv4.host = "192.168.0.24";
          ipv6.host = "2001:db8::1";
        };

        secondary = {
          interface = "enp4s0";
        };

        tailscale = {
          interface = "tailscale0";
          ipv6 = rec {
            host = "fd7a:115c:a1e0::8501:3aa9";
            prefixLength = 128;
            address = "${host}/${builtins.toString prefixLength}";
          };
          ipv4 = rec {
            cidr = "100.64.0.0/10";
            host = "100.69.0.1";
            prefixLength = 32;
            address = "${host}/${builtins.toString prefixLength}";
          };
        };
      };

      wireguard = {
        listenPort = 51820;
      };

      ssh = {
        listenPort = 24212;
        listenAddresses = [
          network.tailscale.ipv4.host
        ];
        listenWildcardIPv4 = null;
        listenWildcardIPv6 = null;
      };

      nixBuild = {
        enable = true;
        systems = [ "x86_64-linux" ];
        maxJobs = 8;
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

    yixiaoqing = rec {
      hostName = "yixiaoqing";

      network = {
        tailscale = {
          interface = "tailscale0";
          ipv4 = rec {
            host = "100.69.0.3";
            prefixLength = 32;
            address = "${host}/${builtins.toString prefixLength}";
          };
        };
      };

      ssh = {
        listenPort = 24212;
        listenAddresses = [
          network.tailscale.ipv4.host
        ];
        listenWildcardIPv4 = null;
        listenWildcardIPv6 = null;
      };

      nixBuild = {
        enable = true;
        systems = [ "x86_64-linux" ];
        maxJobs = 8;
      };
    };

    yitaishi = rec {
      hostName = "yitaishi";

      network = {
        tailscale = {
          interface = "tailscale0";
          ipv4 = rec {
            host = "100.69.0.4";
            prefixLength = 32;
            address = "${host}/${builtins.toString prefixLength}";
          };
        };
      };

      ssh = {
        listenPort = 24212;
        listenAddresses = [
          network.tailscale.ipv4.host
        ];
        listenWildcardIPv4 = null;
        listenWildcardIPv6 = null;
      };

      nixBuild = {
        enable = true;
        systems = [ "x86_64-linux" ];
        maxJobs = 16;
      };
    };
  };
}
