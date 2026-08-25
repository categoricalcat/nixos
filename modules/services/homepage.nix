{
  config,
  allAddresses,
  ...
}:

let
  inherit (config.networking) hostName;
  addrs = allAddresses.hosts.${hostName};

  # Yifuwuqi services
  serviceDomains = {
    jellyfin = "https://${addrs.services.jellyfin.domain}";
    jellyseerr = "https://${addrs.services.jellyseerr.domain}";
    sonarr = "https://${addrs.services.sonarr.domain}";
    radarr = "https://${addrs.services.radarr.domain}";
    lidarr = "https://${addrs.services.lidarr.domain}";
    readarr = "https://${addrs.services.readarr.domain}";
    prowlarr = "https://${addrs.services.prowlarr.domain}";
    bazarr = "https://${addrs.services.bazarr.domain}";
    torrent-indexer = "https://${addrs.services.torrent-indexer.domain}";
    qbittorrent = "https://${addrs.services.qbittorrent.domain}";
    slskd = "https://${addrs.services.slskd.domain}";
    grafana = "https://${addrs.services.grafana.domain}";
    cockpit = "https://${addrs.services.cockpit.domain}";
    forgejo = "https://${addrs.services.forgejo.domain}";
    attic = "https://${addrs.services.attic.domain}";
    docs = "https://${addrs.services.docs.domain}";
  };

  # Network/Proxy services (via yirukou NGINX config)
  proxyDomains = {
    adguard = "https://adguard.fufu.land";
    # netdata = "https://netdata.fufu.land";
    searxng = "https://search.fufu.land";
    portainer = "https://prtnr.fufu.land";
    opencode = "https://agent.fufu.land";
    goaccess = "https://goaccess.fufu.land";
  };
in
{
  services.homepage-dashboard = {
    enable = true;
    listenPort = addrs.services.homepage.port;
    allowedHosts = addrs.services.homepage.domain;

    settings = {
      title = "The Dashboard";
      theme = "dark";
      layout = {
        "Media" = {
          style = "row";
          columns = 4;
        };
        "Arr Stack" = {
          style = "row";
          columns = 4;
        };
        "Monitoring" = {
          style = "row";
          columns = 4;
        };
        "Infrastructure" = {
          style = "row";
          columns = 4;
        };
        "Network" = {
          style = "row";
          columns = 4;
        };
      };
    };

    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
        };
      }
      {
        search = {
          provider = "custom";
          url = "https://search.fufu.land/search?q=";
          target = "_blank";
        };
      }
    ];

    bookmarks = [
      {
        Developer = [
          {
            Github = [
              {
                abbr = "GH";
                href = "https://github.com/";
              }
            ];
          }
        ];
      }
    ];

    services = [
      {
        "Media" = [
          {
            "Jellyfin" = {
              icon = "jellyfin.png";
              href = serviceDomains.jellyfin;
              ping = serviceDomains.jellyfin;
            };
          }
          {
            "Jellyseerr" = {
              icon = "jellyseerr.png";
              href = serviceDomains.jellyseerr;
              ping = serviceDomains.jellyseerr;
            };
          }
        ];
      }
      {
        "Arr Stack" = [
          {
            "Sonarr" = {
              icon = "sonarr.png";
              href = serviceDomains.sonarr;
              ping = serviceDomains.sonarr;
            };
          }
          {
            "Radarr" = {
              icon = "radarr.png";
              href = serviceDomains.radarr;
              ping = serviceDomains.radarr;
            };
          }
          {
            "Lidarr" = {
              icon = "lidarr.png";
              href = serviceDomains.lidarr;
              ping = serviceDomains.lidarr;
            };
          }
          {
            "Readarr" = {
              icon = "readarr.png";
              href = serviceDomains.readarr;
              ping = serviceDomains.readarr;
            };
          }
          {
            "Bazarr" = {
              icon = "bazarr.png";
              href = serviceDomains.bazarr;
              ping = serviceDomains.bazarr;
            };
          }
          {
            "Prowlarr" = {
              icon = "prowlarr.png";
              href = serviceDomains.prowlarr;
              ping = serviceDomains.prowlarr;
            };
          }
          {
            "Torrent Indexer" = {
              icon = "prowlarr.png";
              href = serviceDomains.torrent-indexer;
              ping = serviceDomains.torrent-indexer;
            };
          }
          {
            "qBittorrent" = {
              icon = "qbittorrent.png";
              href = serviceDomains.qbittorrent;
              ping = serviceDomains.qbittorrent;
            };
          }
          {
            "Soulseek" = {
              icon = "slskd.png";
              href = serviceDomains.slskd;
              ping = serviceDomains.slskd;
            };
          }
        ];
      }
      {
        "Monitoring" = [
          {
            "Grafana" = {
              icon = "grafana.png";
              href = serviceDomains.grafana;
              ping = serviceDomains.grafana;
            };
          }
          # {
          #   "Netdata" = {
          #     icon = "netdata.png";
          #     href = proxyDomains.netdata;
          #     ping = proxyDomains.netdata;
          #   };
          # }
          {
            "GoAccess" = {
              icon = "goaccess.png";
              href = proxyDomains.goaccess;
              ping = proxyDomains.goaccess;
            };
          }
        ];
      }
      {
        "Infrastructure" = [
          {
            "Cockpit" = {
              icon = "cockpit.png";
              href = serviceDomains.cockpit;
              ping = serviceDomains.cockpit;
            };
          }
          {
            "Portainer" = {
              icon = "portainer.png";
              href = proxyDomains.portainer;
              ping = proxyDomains.portainer;
            };
          }
          {
            "Forgejo" = {
              icon = "gitea.png";
              href = serviceDomains.forgejo;
              ping = serviceDomains.forgejo;
            };
          }
          {
            "Opencode" = {
              icon = "terminal.png";
              href = proxyDomains.opencode;
              ping = proxyDomains.opencode;
            };
          }
          {
            "Attic Cache" = {
              icon = "nixos.png";
              href = serviceDomains.attic;
              ping = serviceDomains.attic;
            };
          }
          {
            "Docs" = {
              icon = "gitbook.png";
              href = serviceDomains.docs;
              ping = serviceDomains.docs;
            };
          }
        ];
      }
      {
        "Network" = [
          {
            "AdGuard Home" = {
              icon = "adguard-home.png";
              href = proxyDomains.adguard;
              ping = proxyDomains.adguard;
            };
          }
          {
            "SearXNG" = {
              icon = "searxng.png";
              href = proxyDomains.searxng;
              ping = proxyDomains.searxng;
            };
          }
        ];
      }
    ];
  };
}
