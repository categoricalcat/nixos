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

  sharedServices = {
    adguardhome = {
      domain = "adguard.fufu.land";
      port = 3333;
      dnsPort = 53;
    };
  };

  nodeTextfileDir = "/var/lib/prometheus-node-exporter/textfile";

  # All persistent monitoring state on the central host lives under one root
  # (grafana's DB is in postgres, see hosts.yifuwuqi.services.postgresql).
  monitoringDataRoot = "/persist/monitoring";

  internetProbes = {
    icmp = [
      "1.1.1.1"
      "8.8.8.8"
      "216.239.35.0"
      "200.160.0.8"
    ];
    # 127.0.0.1:53 is the local AdGuard -> Unbound chain on both hosts.
    dns = [
      "1.1.1.1:53"
      "8.8.8.8:53"
      "127.0.0.1:53"
    ];
    http = [
      "https://www.google.com/generate_204"
      "https://cp.cloudflare.com"
    ];
  };

in
{
  monitoring = {
    centralHost = "yifuwuqi";
    proxyHost = "yirukou";
    inherit nodeTextfileDir;
    dataRoot = monitoringDataRoot;
    dataDirs = {
      prometheus = "${monitoringDataRoot}/prometheus";
      loki = "${monitoringDataRoot}/loki";
      grafana = "${monitoringDataRoot}/grafana";
    };
    probes = internetProbes;
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
        settings = {
          enabledCollectors = [ "systemd" ];
          extraFlags = [ "--collector.textfile.directory=${nodeTextfileDir}" ];
        };
      };

      # smokeping labels its ping target `host`, which collides with our
      # origin `host` label; Prometheus renames it `exported_host`, we
      # expose it as `target`.
      smokeping = {
        hosts = "scrapeHosts";
        settings.hosts = internetProbes.icmp;
        metricRelabelConfigs = [
          {
            source_labels = [ "exported_host" ];
            target_label = "target";
          }
          {
            regex = "exported_host";
            action = "labeldrop";
          }
        ];
      };

      # Probe jobs live in prometheus.nix (`probe` job, modules from blackbox.yml).
      blackbox = {
        hosts = "scrapeHosts";
        settings.configFile = ./services/monitoring/blackbox.yml;
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

      postgres = {
        hosts = "centralHost";
        settings.dataSourceName = "postgres://postgres@127.0.0.1:5432/postgres?sslmode=disable";
      };

      adguard = {
        hosts = "scrapeHosts";
      };

      unbound = {
        hosts = "scrapeHosts";
        settings.unbound = {
          host = "unix:///run/unbound/unbound.ctl";
          ca = null;
          certificate = null;
          key = null;
        };
      };

      # Shared valkey (unbound cachedb DNS cache + searxng). Runs only on the
      # central host, reaches the instance locally over its unix socket. Key name must match the
      # nixpkgs exporter module (services.prometheus.exporters.redis).
      redis = {
        hosts = "centralHost";
        settings = {
          # Runs as the valkey server user so it can open the unix socket
          # (owned redis:redis mode 660, under /run/redis).
          user = "redis";
          extraFlags = [
            "-redis.addr"
            "unix:///run/redis/redis.sock"
          ];
        };
      };
    };
  };

  hosts = {
    yifuwuqi = rec {
      hostName = "yifuwuqi";

      dns = {
        threads = 6; # unbound num-threads on this host
        systemNameservers = [
          "10.42.0.1"
          "127.0.0.1"
        ];
        domain = "vpn";
      }
      // sharedDnsUpstreams;

      network = rec {
        vpn = tailscale;

        netbird = {
          domain = "nb";
          interface = "wt0";
          ipv4 = rec {
            cidr = "100.42.0.0/16";
            host = "100.42.0.2";
            prefixLength = 16;
            address = "${host}/${toString prefixLength}";
          };
        };

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
          domain = "ts";
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
        pingTargets = [
          "216.239.35.0"
          "200.160.0.8"
        ];
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
          port = 24030;
        };
        prometheus = {
          port = 24090;
        };
        cockpit = {
          domain = "cockpit.fufu.land";
          port = 24091;
        };
        loki = {
          port = 24100;
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
          httpPort = 24200;
        };
        attic = {
          domain = "cache.fufu.land";
          port = 24203;
          cacheName = "yi";
        };
        radarr = {
          domain = "radarr.fufu.land";
          port = 24878;
        };
        sonarr = {
          domain = "sonarr.fufu.land";
          port = 24989;
        };
        lidarr = {
          domain = "lidarr.fufu.land";
          port = 24686;
        };
        readarr = {
          domain = "readarr.fufu.land";
          port = 24787;
        };
        prowlarr = {
          domain = "prowlarr.fufu.land";
          port = 24696;
        };
        torrent-indexer = {
          domain = "torrent-indexer.fufu.land";
          port = 24181;
        };
        bazarr = {
          domain = "bazarr.fufu.land";
          port = 24767;
        };
        jellyfin = {
          domain = "jellyfin.fufu.land";
          port = 24096;
        };
        jellyseerr = {
          domain = "jellyseerr.fufu.land";
          port = 24055;
        };
        flaresolverr = {
          domain = "flaresolverr.fufu.land";
          port = 24191;
          # Gluetun netns listen port; host publish is `port:internalPort`.
          internalPort = 8191;
        };
        qbittorrent = {
          domain = "qbittorrent.fufu.land";
          port = 24080;
        };
        slskd = {
          domain = "slskd.fufu.land";
          # 24030 is taken by grafana, so this one keeps its leading 5
          port = 24530;
          listenPort = 2234;
        };
        homepage = {
          domain = "home.fufu.land";
          port = 24082;
        };
        adguardhome = sharedServices.adguardhome // {
          port = 24333;
          dnsBindHosts = [
            "127.0.0.1"
            "10.42.0.2"
            "100.69.0.6"
            "100.42.0.2"
          ];
        };
        searxng = {
          domain = "search.fufu.land";
          port = 24888;
        };
        valkey = {
          port = 24379;
          host = network.lan.ipv4.host;
        };
        opencode = {
          port = 24010;
        };
        firecrawl = {
          port = 24002;
        };
        sillytavern = {
          domain = "companion.fufu.land";
          port = 24000;
        };
        docs = {
          domain = "docs.fufu.land";
          port = 24083;
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
        vpn = tailscale;
        netbird = {
          domain = "nb";
          interface = "wt0";
          ipv4 = rec {
            cidr = "100.42.0.0/16";
            host = "100.42.0.4";
            prefixLength = 16;
            address = "${host}/${toString prefixLength}";
          };
        };

        tailscale = {
          domain = "ts";
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
        vpn = tailscale;
        netbird = {
          domain = "nb";
          interface = "wt0";
          ipv4 = rec {
            cidr = "100.42.0.0/16";
            host = "100.42.0.3";
            prefixLength = 16;
            address = "${host}/${toString prefixLength}";
          };
        };

        tailscale = {
          domain = "ts";
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
        threads = 6; # unbound num-threads on this host
        systemNameservers = [ "127.0.0.1" ];
        lanServers = [
          "10.42.0.1"
          "10.42.0.2"
        ];
        fallbackServers = [
          "${builtins.elemAt sharedDnsUpstreams.quad9 5}:53"
          "${builtins.elemAt sharedDnsUpstreams.quad9 6}:53"
          "[${builtins.elemAt sharedDnsUpstreams.quad9 7}]:53"
        ];
      }
      // sharedDnsUpstreams;

      network = rec {
        vpn = tailscale;
        netbird = {
          domain = "nb";
          interface = "wt0";
          ipv4 = rec {
            cidr = "100.42.0.0/16";
            host = "100.42.0.1";
            prefixLength = 16;
            address = "${host}/${toString prefixLength}";
          };
        };

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
          domain = "ts";
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
        pingTargets = [
          "216.239.35.0"
          "200.160.0.8"
        ];
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

      services = {
        adguardhome = sharedServices.adguardhome // {
          dnsBindHosts = [
            "127.0.0.1"
            "10.42.0.1"
            "10.42.42.1"
            "100.69.0.1"
            "100.42.0.1"
          ];
        };
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
