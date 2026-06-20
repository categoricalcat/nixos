{
  allAddresses,
  config,
  ...
}:

let
  inherit (allAddresses) monitoring;
  centralHost = allAddresses.hosts.${monitoring.centralHost};
  inherit (centralHost) services;
  inherit (services) grafana;
  inherit (services) prometheus;
  inherit (services) loki;
in
{
  assertions = [
    {
      assertion = config.networking.hostName == monitoring.centralHost;
      message = "modules/services/monitoring/grafana.nix: may only be imported on ${monitoring.centralHost}";
    }
  ];

  sops.secrets."services/grafana/secret-key" = {
    owner = "grafana";
    group = "grafana";
    mode = "0400";
  };

  services.grafana = {
    enable = true;

    settings = {
      analytics.reporting_enabled = false;

      server = {
        http_addr = centralHost.network.lan.ipv4.host;
        http_port = grafana.port;
        inherit (grafana) domain;
        root_url = "https://${grafana.domain}/";
      };

      auth.disable_login_form = true;
      "auth.anonymous" = {
        enabled = true;
        org_role = "Viewer";
      };

      security = {
        disable_initial_admin_creation = true;
        secret_key = "$__file{${config.sops.secrets."services/grafana/secret-key".path}}";
        cookie_secure = true;
        disable_gravatar = true;
      };
    };

    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        prune = true;
        datasources = [
          {
            name = "Prometheus";
            uid = "prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:${toString prometheus.port}";
            isDefault = true;
          }
          {
            name = "Loki";
            uid = "loki";
            type = "loki";
            access = "proxy";
            url = "http://${centralHost.network.lan.ipv4.host}:${toString loki.port}";
          }
        ];
      };
    };
  };

  systemd.services.grafana = {
    wants = [
      "prometheus.service"
      "loki.service"
    ];
    after = [
      "prometheus.service"
      "loki.service"
    ];
  };
}
