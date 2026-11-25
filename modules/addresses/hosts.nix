# Per-host registry: network placement, SSH, build roles, and service
# entries. Consumed via modules/addresses.nix.
{
  baseDomain,
  sharedDnsUpstreams,
}:
let
  mkAddr = host: prefixLength: {
    inherit host prefixLength;
    address = "${host}/${toString prefixLength}";
  };

  mkDhcpPool = start: end: {
    inherit start end;
    range = "${start} - ${end}";
  };

  mkTailscaleIpv4 = host: {
    domain = "ts";
    interface = "tailscale0";
    ipv4 = mkAddr host 32;
  };

  mkSsh = listenAddresses: {
    listenPort = 24212;
    inherit listenAddresses;
  };

  mkNixBuild =
    {
      useRemoteBuilders ? true,
      remoteBuilder,
      maxJobs,
      speedFactor,
    }:
    {
      enable = true;
      inherit
        useRemoteBuilders
        remoteBuilder
        maxJobs
        speedFactor
        ;
      systems = [ "x86_64-linux" ];
    };

  sharedServices = {
    llama-cpp.port = 11436;
    valkey.port = 24379;
    # Internal mTLS ingress: one port on both hosts, serving the application
    # vhosts on yifuwuqi and the machine-scrape paths on both.
    ingress.port = 24120;
  };

  # Off-net addresses each failover host pings to judge its primary uplink
  # (packages/gateway-failover/default.nix).
  failoverPingTargets = [
    "216.239.35.0"
    "200.160.0.8"
  ];

  # RFC 7534 AS112 sinkhole addresses returned by AdGuard custom-IP blocking.
  sinkhole = {
    ipv4.host = "192.175.48.1";
    ipv6.host = "2620:4f:8000::1";
  };

  lanIpv4Cidr = "10.42.0.0/24";
  lanIpv6Cidr = "fd75:c55f:6d19:1::/64";
  yirukouLanIpv4 = "10.42.0.1";
  yirukouLanIpv6 = "fd75:c55f:6d19:1::1";
  yifuwuqiLanIpv4 = "10.42.0.2";
  yifuwuqiLanIpv6 = "fd75:c55f:6d19:1::2";
in
{
  yifuwuqi =
    let
      tsIpv4 = "100.69.0.6";
      lanInterface = "eno1";
      secondaryInterface = "enp4s0";
      secondaryGateway = "192.168.0.1";
      tailscale = {
        domain = "ts";
        interface = "tailscale0";
        ipv6 = mkAddr "fd7a:115c:a1e0::8501:3aa9" 128;
        ipv4 = mkAddr tsIpv4 32 // {
          cidr = "100.64.0.0/10";
        };
      };
      pgSocketDir = "/run/postgresql";
      pgDatabases = {
        forgejo = "forgejo";
        atticd = "atticd";
        grafana = "grafana";
        authelia = "authelia";
      };
      defaultContainerSubnet = "10.88.0.0/16";
      containerSubnetPools = [
        {
          base = "172.17.0.0/16";
          size = 24;
        }
        {
          base = "172.18.0.0/16";
          size = 24;
        }
      ];
      cloudflaredCidr = "10.89.0.0/24";
      # Fixed so the firewall can name gluetun alone: it owns the network
      # namespace that qBittorrent, slskd, soularr and torrent-indexer share.
      gluetunCidr = "172.19.0.0/24";
      applicationSourceSubnets = [
        defaultContainerSubnet
      ]
      ++ map (pool: pool.base) containerSubnetPools;
    in
    {
      hostName = "yifuwuqi";
      # deploy-rs target; nix/deploy.nix derives its node list from this flag.
      # yichuang is absent from the registry entirely, so WSL stays out of deploy-rs.
      deploy = true;

      dns = {
        port = 53;
        lanUpstreams = [
          yirukouLanIpv6
          yirukouLanIpv4
        ];
        # Extra stub listeners for LAN/Tailscale secondary DNS and Podman
        # containers; avoids wildcard bind so aardvark-dns keeps container
        # bridge gateways (172.17.x.1, 10.89.0.1).
        stubListenAddresses = [
          "::1"
          yifuwuqiLanIpv6
          "127.0.0.1"
          yifuwuqiLanIpv4
          tsIpv4
        ];
        domain = "vpn";
      };

      network = {
        vpn = tailscale;
        inherit tailscale sinkhole;

        lan = {
          interface = lanInterface;
          ipv6 = mkAddr yifuwuqiLanIpv6 64 // {
            cidr = lanIpv6Cidr;
          };
          ipv4 = mkAddr yifuwuqiLanIpv4 24 // {
            gateway = yirukouLanIpv4;
          };
        };

        # Fallback uplink. The host address is DHCP-assigned; only the subnet
        # and its router are fixed. That router's admin UI is advertised to
        # the tailnet from here (see hosts/yifuwuqi/services.nix).
        secondary = {
          interface = secondaryInterface;
          # Above gatewayFailover.primary.metric, so this default route only
          # wins once the primary's is withdrawn.
          routeMetric = 200;
          ipv4 = {
            cidr = "192.168.0.0/24";
            prefixLength = 24;
            gateway = secondaryGateway;
            gatewayRoute = "${secondaryGateway}/32";
          };
        };
      };

      gatewayFailover = {
        primary = {
          interface = lanInterface;
          gateway = yirukouLanIpv4;
          metric = 100;
        };
        fallback.interface = secondaryInterface;
        pingTargets = failoverPingTargets;
      };

      # Plain SSH over the LAN and the tailnet subnet route, not the
      # Cloudflare tunnel (cloudflare.aset.love).
      ssh =
        mkSsh [
          tsIpv4
          yifuwuqiLanIpv6
          yifuwuqiLanIpv4
        ]
        // {
          domain = "ssh.${baseDomain}";
        };

      services = {
        grafana = {
          name = "Grafana";
          group = "Monitoring";
          desktopIcon = "utilities-system-monitor.svg";
          domain = "grafana.${baseDomain}";
          port = 24030;
        };
        prometheus.port = 24090;
        cockpit = {
          name = "Cockpit";
          group = "Infrastructure";
          desktopIcon = "applications-system.svg";
          domain = "cockpit.${baseDomain}";
          port = 24091;
        };
        loki.port = 24100;
        postgresql = {
          packageAttr = "postgresql_18";
          socketDir = pgSocketDir;
          dataRoot = "/persist/postgresql";
          databases = pgDatabases;
          urls.atticd = "postgres://atticd@localhost/${pgDatabases.atticd}?host=${pgSocketDir}";
        };
        forgejo = {
          name = "Forgejo";
          group = "Infrastructure";
          icon = "gitea.png";
          desktopIcon = "git.svg";
          domain = "forgejo.${baseDomain}";
          httpPort = 24200;
        };
        attic = {
          name = "Attic Cache";
          group = "Infrastructure";
          icon = "nixos.png";
          desktopIcon = "distributor-logo-nixos.svg";
          domain = "attic.${baseDomain}";
          port = 24203;
          cacheName = "yi";
        };
        radarr = {
          name = "Radarr";
          group = "Arr Stack";
          desktopIcon = "deepin-movie.svg";
          domain = "radarr.${baseDomain}";
          port = 24878;
        };
        sonarr = {
          name = "Sonarr";
          group = "Arr Stack";
          desktopIcon = "me-tv.svg";
          domain = "sonarr.${baseDomain}";
          port = 24989;
        };
        lidarr = {
          name = "Lidarr";
          group = "Arr Stack";
          desktopIcon = "multimedia-audio-player.svg";
          domain = "lidarr.${baseDomain}";
          port = 24686;
        };
        readarr = {
          name = "Readarr";
          group = "Arr Stack";
          desktopIcon = "accessories-ebook-reader.svg";
          domain = "readarr.${baseDomain}";
          port = 24787;
        };
        prowlarr = {
          name = "Prowlarr";
          group = "Arr Stack";
          desktopIcon = "preferences-system-search.svg";
          domain = "prowlarr.${baseDomain}";
          port = 24696;
        };
        torrent-indexer = {
          name = "Torrent Indexer";
          group = "Arr Stack";
          icon = "prowlarr.png";
          desktopIcon = "preferences-system-search.svg";
          domain = "torrent-indexer.${baseDomain}";
          port = 24181;
        };
        bazarr = {
          name = "Bazarr";
          group = "Arr Stack";
          desktopIcon = "gnome-subtitles.svg";
          domain = "bazarr.${baseDomain}";
          port = 24767;
        };
        jellyfin = {
          name = "Jellyfin";
          group = "Media";
          domain = "jellyfin.${baseDomain}";
          port = 24096;
        };
        jellyseerr = {
          name = "Jellyseerr";
          group = "Media";
          desktopIcon = "multimedia-video-player.svg";
          domain = "jellyseerr.${baseDomain}";
          port = 24055;
        };
        pinepods = {
          name = "Pinepods";
          group = "Media";
          desktopIcon = "podcast.svg";
          domain = "pinepods.${baseDomain}";
          port = 24085;
        };
        flaresolverr = {
          domain = "flaresolverr.${baseDomain}";
          port = 24191;
          # Gluetun netns listen port; host publish is `port:internalPort`.
          internalPort = 8191;
        };
        # Gluetun's HTTP proxy. No domain and no group on purpose: it is not a
        # web UI, so the homepage dashboard, the desktop web-app list, and the
        # proxy-vhost list all skip it.
        gluetun = {
          port = 8889;
          internalPort = 8888;
        };
        qbittorrent = {
          name = "qBittorrent";
          group = "Arr Stack";
          domain = "qbittorrent.${baseDomain}";
          port = 24080;
        };
        slskd = {
          name = "Soulseek";
          group = "Arr Stack";
          desktopIcon = "soulseek.svg";
          domain = "slskd.${baseDomain}";
          # 24030 is taken by grafana, so this one keeps its leading 5
          port = 24530;
          listenPort = 2234;
        };
        homepage = {
          name = "Homepage";
          desktopIcon = "kfm_home.svg";
          domain = "homepage.${baseDomain}";
          port = 24082;
        };
        searxng = {
          name = "SearXNG";
          group = "Network";
          desktopIcon = "preferences-system-search.svg";
          domain = "searxng.${baseDomain}";
          port = 24888;
        };
        opencode = {
          name = "Opencode";
          group = "Infrastructure";
          icon = "terminal.png";
          desktopIcon = "utilities-terminal.svg";
          domain = "opencode.${baseDomain}";
          port = 24010;
        };
        # One nginx listener on the LAN address fronts every proxied backend
        # (local ingress); yirukou proxies each domain to it over mTLS.
        inherit (sharedServices) ingress;
        firecrawl.port = 24002;
        inherit (sharedServices) llama-cpp;
        valkey = {
          inherit (sharedServices.valkey) port;
          # No unbound cachedb here. Cap for local consumers.
          maxMemory = "512mb";
        };
        sillytavern = {
          name = "SillyTavern";
          group = "Infrastructure";
          desktopIcon = "internet-chat.svg";
          domain = "sillytavern.${baseDomain}";
          port = 24000;
        };
        docs = {
          name = "Docs";
          group = "Infrastructure";
          icon = "gitbook.png";
          desktopIcon = "devdocs.svg";
          domain = "docs.${baseDomain}";
          port = 24083;
        };
        authelia = {
          name = "Authelia";
          group = "Infrastructure";
          desktopIcon = "security-high.svg";
          domain = "authelia.${baseDomain}";
          port = 24140;
        };
      };

      nixBuild = mkNixBuild {
        remoteBuilder = true;
        maxJobs = 16;
        speedFactor = 240;
      };

      containers = {
        defaultSubnet = defaultContainerSubnet;
        subnetPools = containerSubnetPools;
        cloudflared.network = {
          name = "cloudflared";
          interface = "cloudflared0";
          ipv4 = {
            cidr = cloudflaredCidr;
            gateway = "10.89.0.1";
            host = "10.89.0.2";
          };
        };
        gluetun.network = {
          name = "gluetun";
          interface = "gluetun0";
          ipv4 = {
            cidr = gluetunCidr;
            gateway = "172.19.0.1";
            host = "172.19.0.2";
          };
        };

        isolation = {
          inherit applicationSourceSubnets;
          # gluetun is deliberately absent from applicationSourceSubnets: its
          # shared namespace makes it a caller in its own right, admitted to
          # DNS and to Lidarr only.
          sourceSubnets = applicationSourceSubnets ++ [
            cloudflaredCidr
            gluetunCidr
          ];
        };
      };
    };

  yixiaoqing =
    let
      tailscale = mkTailscaleIpv4 "100.69.0.3";
    in
    {
      hostName = "yixiaoqing";
      deploy = true;

      network = {
        vpn = tailscale;
        inherit tailscale;
      };

      ssh = mkSsh [ tailscale.ipv4.host ];

      nixBuild = mkNixBuild {
        remoteBuilder = false;
        maxJobs = 8;
        speedFactor = 180;
      };
    };

  yitaishi =
    let
      tailscale = mkTailscaleIpv4 "100.69.0.4";
    in
    {
      hostName = "yitaishi";
      deploy = true;

      network = {
        vpn = tailscale;
        inherit tailscale;
      };

      ssh = mkSsh [ tailscale.ipv4.host ];

      nixBuild = mkNixBuild {
        remoteBuilder = true;
        maxJobs = 16;
        speedFactor = 360;
      };

      services = {
        inherit (sharedServices) llama-cpp;
        sd-cpp = {
          domain = "sd-cpp.${baseDomain}";
          port = 11437;
        };
      };
    };

  yirukou =
    let
      tailscale = mkTailscaleIpv4 "100.69.0.1";
      wanPrimary = {
        interface = "enp7s0";
        routeMetric = 100;
      };
      wanFallback = {
        interface = "enp6s0";
        routeMetric = 200;
      };
      untrustedParent = "enp2s0";
      untrustedVlanId = 42;
      untrustedIpv6 = "fd75:c55f:6d19:2::1";
      untrustedIpv4 = "10.42.42.1";
    in
    {
      hostName = "yirukou";
      deploy = true;

      dns = {
        threads = 6; # unbound num-threads on this host
        systemNameservers = [
          "::1"
          "127.0.0.1"
        ];
        lanServers = [
          yirukouLanIpv4
          yifuwuqiLanIpv4
        ];
        fallbackServers = [
          "${builtins.elemAt sharedDnsUpstreams.quad9 5}:53"
          "${builtins.elemAt sharedDnsUpstreams.quad9 6}:53"
          "[${builtins.elemAt sharedDnsUpstreams.quad9 7}]:53"
        ];
      }
      // sharedDnsUpstreams;

      network = {
        vpn = tailscale;
        inherit tailscale sinkhole;

        wan = {
          primary = wanPrimary;
          fallback = wanFallback;
        };

        lan = {
          interface = "br0";
          ports = [
            "enp5s0"
            "enp4s0"
            "enp3s0"
            "enp2s0"
          ];
          ipv6 = mkAddr yirukouLanIpv6 64 // {
            cidr = lanIpv6Cidr;
          };
          ipv4 = mkAddr yirukouLanIpv4 24 // {
            cidr = lanIpv4Cidr;
          };
          dhcp.pool = mkDhcpPool "10.42.0.100" "10.42.0.250";
        };

        untrusted = {
          parentInterface = untrustedParent;
          vlanId = untrustedVlanId;
          interface = "${untrustedParent}.${toString untrustedVlanId}";
          ipv6 = mkAddr untrustedIpv6 64 // {
            cidr = "fd75:c55f:6d19:2::/64";
          };
          ipv4 = mkAddr untrustedIpv4 24 // {
            cidr = "10.42.42.0/24";
          };
          dhcp.pool = mkDhcpPool "10.42.42.100" "10.42.42.250";
        };
      };

      gatewayFailover = {
        primary = {
          inherit (wanPrimary) interface;
          # Read from the DHCP lease.
          gateway = null;
          metric = wanPrimary.routeMetric;
        };
        fallback = {
          inherit (wanFallback) interface;
        };
        pingTargets = failoverPingTargets;
      };

      ssh = mkSsh [
        tailscale.ipv4.host
        yirukouLanIpv6
        yirukouLanIpv4
      ];

      nixBuild = mkNixBuild {
        useRemoteBuilders = false;
        remoteBuilder = false;
        maxJobs = 1;
        speedFactor = 60;
      };

      services = {
        # Machine-scrape ingress: the central host scrapes every exporter here
        # over mTLS, so no exporter port is exposed to the LAN.
        inherit (sharedServices) ingress;
        adguardhome = {
          name = "AdGuard Home";
          group = "Network";
          icon = "adguard-home.png";
          domain = "adguardhome.${baseDomain}";
          port = 3333;
          dnsPort = 53;
          dnsBindHosts = [
            "::1"
            yirukouLanIpv6
            untrustedIpv6
            "127.0.0.1"
            yirukouLanIpv4
            untrustedIpv4
            tailscale.ipv4.host
          ];
        };
        # yirukou is the primary LAN resolver, so it gets the larger L2 cap.
        # Ceiling, not a reservation: the db self-cleans via unbound's EX TTLs
        # and sits far below this (~1-15 MiB) unless a key flood outpaces
        # expiry. This box has 7.5 GiB total and also carries unbound's 300m
        # msg + 600m rrset in-memory caches.
        valkey = {
          inherit (sharedServices.valkey) port;
          maxMemory = "1gb";
        };
      };
    };
}
