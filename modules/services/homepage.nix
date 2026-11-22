{
  config,
  allAddresses,
  lib,
  ...
}:

let
  addrs = allAddresses.hosts.${config.networking.hostName};

  groups = [
    "Media"
    "Arr Stack"
    "Monitoring"
    "Infrastructure"
    "Network"
  ];

  dashboardServices = addrs.services // {
    inherit (allAddresses.hosts.yirukou.services) adguardhome;
    goaccess = {
      name = "GoAccess";
      group = "Monitoring";
      domain = "goaccess.${allAddresses.baseDomain}";
    };
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
      layout = lib.genAttrs groups (_: {
        style = "row";
        columns = 4;
      });
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
          url = "https://${addrs.services.searxng.domain}/search?q=";
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

    services = map (group: {
      ${group} = lib.mapAttrsToList (
        id: s:
        let
          url = "https://${s.domain}";
        in
        {
          ${s.name} = {
            icon = s.icon or "${id}.png";
            href = url;
            ping = url;
          };
        }
      ) (lib.filterAttrs (_: s: (s.group or null) == group) dashboardServices);
    }) groups;
  };
}
