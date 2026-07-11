let

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
  monitoring = {
    centralHost = "yifuwuqi";
    proxyHost = "yirukou";
    scrapeHosts = [
      "yifuwuqi"
      "yirukou"
    ];
    logHosts = [
      "yifuwuqi"
      "yirukou"
    ];
    exporters = {
      node = {
        hosts = "scrapeHosts";
        settings.enabledCollectors = [ "systemd" ];
      };

      systemd.hosts = "scrapeHosts";

      smartctl = {
        hosts = "scrapeHosts";
        scrapeInterval = "60s";
        settings.maxInterval = "5m";
      };

      nginx = {
        hosts = "proxyHost";
        settings.scrapeUri = "http://127.0.0.1/nginx_status";
      };

      fail2ban = {
        hosts = "centralHost";
        settings.exitOnError = false;
      };
    };
  };

  hosts = {
    yifuwuqi = rec {
      hostName = "yifuwuqi";

      dns = {
        systemNameservers = [
          "10.42.0.1"
          "127.0.0.1"
        ];
        domain = "vpn";
      }
      // sharedDnsUpstreams;

      network = rec {

        netbird = {
          interface = "wt0";
          ipv4 = rec {
            cidr = "100.42.0.0/16";
            host = "100.42.0.2";
            prefixLength = 16;
            address = "${host}/${toString prefixLength}";
          };
        };

        vpn = netbird;

        lan = {
          interface = "eno1";
          ipv4 = rec {
            host = "10.42.0.2";
            prefixLength = 24;
            address = "${host}/${toString prefixLength}";
            gateway = "10.42.0.1";
          };
        };

        sinkhole = {
          ipv4.host = "10.42.0.24";
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
            address = "${host}/${toString prefixLength}";
          };
          ipv4 = rec {
            cidr = "100.64.0.0/10";
            host = "100.69.0.6";
            prefixLength = 32;
            address = "${host}/${toString prefixLength}";
          };
        };
      };

      gatewayFailover = {
        primary = {
          inherit (network.lan) interface;
          inherit (network.lan.ipv4) gateway;
          source = network.lan.ipv4.host;
          metric = 100;
        };
        fallback = {
          inherit (network.secondary) interface;
          gateway = null;
          source = null;
          metric = 200;
        };
        pingTarget = "4.2.2.2";
        pingTimeout = 2;
        pingDeadline = 5;
        virtualRouterId = 99;
        priority = 100;
        unicastPeers = [ "127.0.0.1" ];
      };

      ssh = {
        listenPort = 24212;
        listenAddresses = [
          network.tailscale.ipv4.host
          network.netbird.ipv4.host
          network.lan.ipv4.host
        ];
        listenWildcardIPv4 = null;
        listenWildcardIPv6 = null;
      };

      services = {
        grafana = {
          domain = "grafana.fufu.land";
          port = 3030;
        };
        prometheus = {
          port = 9090;
        };
        cockpit = {
          domain = "cockpit.fufu.land";
          port = 9091;
        };
        loki = {
          port = 3100;
        };
        postgresql = rec {
          packageAttr = "postgresql_18";
          socketDir = "/run/postgresql";
          dataRoot = "/persist/postgresql";
          databases = {
            forgejo = "forgejo";
            atticd = "atticd";
            grafana = "grafana";
          };
          urls.atticd = "postgres://atticd@localhost/${databases.atticd}?host=${socketDir}";
        };
        forgejo = {
          domain = "git.fufu.land";
          httpPort = 18200;
        };
        attic = {
          domain = "cache.fufu.land";
          port = 18203;
          cacheName = "yi";
        };
        radarr = {
          domain = "radarr.fufu.land";
          port = 7878;
        };
        sonarr = {
          domain = "sonarr.fufu.land";
          port = 8989;
        };
        lidarr = {
          domain = "lidarr.fufu.land";
          port = 8686;
        };
        readarr = {
          domain = "readarr.fufu.land";
          port = 8787;
        };
        prowlarr = {
          domain = "prowlarr.fufu.land";
          port = 9696;
        };
        bazarr = {
          domain = "bazarr.fufu.land";
          port = 6767;
        };
        qbittorrent = {
          domain = "qbittorrent.fufu.land";
          port = 8080;
        };
      };

      nixBuild = {
        enable = true;
        remoteBuilder = true;
        systems = [ "x86_64-linux" ];
        maxJobs = 16;
        speedFactor = 240;
      };

      containers = rec {
        defaultSubnet = "10.88.0.0/16";
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

        isolation = {
          sourceSubnets = [
            defaultSubnet
          ]
          ++ (map (pool: pool.base) subnetPools);
          blockedDestinationSubnets = [
            "10.0.0.0/8"
            "172.16.0.0/12"
            "192.168.0.0/16"
          ];
        };
      };
    };

    yixiaoqing = rec {
      hostName = "yixiaoqing";

      network = rec {
        netbird = {
          interface = "wt0";
          ipv4 = rec {
            cidr = "100.42.0.0/16";
            host = "100.42.0.4";
            prefixLength = 16;
            address = "${host}/${toString prefixLength}";
          };
        };

        vpn = netbird;

        tailscale = {
          interface = "tailscale0";
          ipv4 = rec {
            host = "100.69.0.3";
            prefixLength = 32;
            address = "${host}/${toString prefixLength}";
          };
        };
      };

      ssh = {
        listenPort = 24212;
        listenAddresses = [
          network.tailscale.ipv4.host
          network.netbird.ipv4.host
        ];
        listenWildcardIPv4 = null;
        listenWildcardIPv6 = null;
      };

      nixBuild = {
        enable = true;
        remoteBuilder = false;
        systems = [ "x86_64-linux" ];
        maxJobs = 8;
        speedFactor = 180;
      };
    };

    yitaishi = rec {
      hostName = "yitaishi";

      network = rec {
        netbird = {
          interface = "wt0";
          ipv4 = rec {
            cidr = "100.42.0.0/16";
            host = "100.42.0.3";
            prefixLength = 16;
            address = "${host}/${toString prefixLength}";
          };
        };

        vpn = netbird;

        tailscale = {
          interface = "tailscale0";
          ipv4 = rec {
            host = "100.69.0.4";
            prefixLength = 32;
            address = "${host}/${toString prefixLength}";
          };
        };
      };

      ssh = {
        listenPort = 24212;
        listenAddresses = [
          network.tailscale.ipv4.host
          network.netbird.ipv4.host
        ];
        listenWildcardIPv4 = null;
        listenWildcardIPv6 = null;
      };

      nixBuild = {
        enable = true;
        remoteBuilder = true;
        systems = [ "x86_64-linux" ];
        maxJobs = 16;
        speedFactor = 360;
      };
    };

    yirukou = rec {
      hostName = "yirukou";

      dns = {
        systemNameservers = [ "127.0.0.1" ];
        lanServers = [
          "10.42.0.1"
          "10.42.0.2"
        ];
        fallbackServers = [
          "9.9.9.9:53"
          "149.112.112.112:53"
          "[2620:fe::fe]:53"
        ];
      }
      // sharedDnsUpstreams;

      network = rec {
        netbird = {
          interface = "wt0";
          ipv4 = rec {
            cidr = "100.42.0.0/16";
            host = "100.42.0.1";
            prefixLength = 16;
            address = "${host}/${toString prefixLength}";
          };
        };

        vpn = netbird;

        wan = {
          primary = {
            interface = "enp7s0";
            routeMetric = 100;
          };
          fallback = {
            interface = "enp6s0";
            routeMetric = 200;
          };
        };

        tailscale = {
          interface = "tailscale0";
          ipv4 = rec {
            host = "100.69.0.1";
            prefixLength = 32;
            address = "${host}/${toString prefixLength}";
          };
        };

        lan = {
          interface = "br0";
          ports = [
            "enp5s0"
            "enp4s0"
            "enp3s0"
            "enp2s0"
          ];
          ipv4 = rec {
            cidr = "10.42.0.0/24";
            host = "10.42.0.1";
            prefixLength = 24;
            address = "${host}/${toString prefixLength}";
          };
          dhcp.pool = rec {
            start = "10.42.0.100";
            end = "10.42.0.250";
            range = "${start} - ${end}";
          };
        };

        untrusted = rec {
          parentInterface = "enp2s0";
          vlanId = 42;
          interface = "${parentInterface}.${toString vlanId}";
          ipv4 = rec {
            cidr = "10.42.42.0/24";
            host = "10.42.42.1";
            prefixLength = 24;
            address = "${host}/${toString prefixLength}";
          };
          dhcp.pool = rec {
            start = "10.42.42.100";
            end = "10.42.42.250";
            range = "${start} - ${end}";
          };
        };

        sinkhole = {
          ipv4.host = "10.42.0.24";
          ipv6.host = "2001:db8::2";
        };
      };

      gatewayFailover = {
        primary = {
          inherit (network.wan.primary) interface;
          gateway = null;
          source = null;
          metric = network.wan.primary.routeMetric;
        };
        fallback = {
          inherit (network.wan.fallback) interface;
          gateway = null;
          source = null;
          metric = network.wan.fallback.routeMetric;
        };
        pingTarget = "1.1.1.1";
        pingTimeout = 2;
        pingDeadline = 5;
        virtualRouterId = 99;
        priority = 100;
        unicastPeers = [ "127.0.0.1" ];
      };

      ssh = {
        listenPort = 24212;
        listenAddresses = [
          network.tailscale.ipv4.host
          network.netbird.ipv4.host
          network.lan.ipv4.host
        ];
        listenWildcardIPv4 = null;
        listenWildcardIPv6 = null;
      };

      nixBuild = {
        enable = true;
        remoteBuilder = false;
        systems = [ "x86_64-linux" ];
        maxJobs = 1;
        speedFactor = 60;
      };
    };
  };

  aliases = [
    {
      suffix = "lan";
      path = [
        "network"
        "lan"
        "ipv4"
        "host"
      ];
    }
    {
      suffix = "local";
      path = [
        "network"
        "lan"
        "ipv4"
        "host"
      ];
    }
    {
      suffix = "vpn";
      path = [
        "network"
        "vpn"
        "ipv4"
        "host"
      ];
    }
    {
      suffix = "ts";
      path = [
        "network"
        "tailscale"
        "ipv4"
        "host"
      ];
    }
    {
      suffix = "nb";
      path = [
        "network"
        "netbird"
        "ipv4"
        "host"
      ];
    }
  ];
}
