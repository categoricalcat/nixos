{
  allAddresses,
  config,
  pkgs,
  ...
}:

let
  inherit (allAddresses) monitoring;
  centralHost = allAddresses.hosts.${monitoring.centralHost};
  inherit (centralHost) services;
  inherit (services) grafana prometheus loki;
in
{
  sops.secrets."services/grafana/secret-key" = {
    owner = "grafana";
    group = "grafana";
    mode = "0400";
  };

  services.grafana = {
    enable = true;

    settings = {
      analytics.reporting_enabled = false;
      log = {
        mode = "console";
        level = "debug";
      };

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
        prune = false;
        datasources = [
          {
            name = "Prometheus";
            orgId = 1;
            uid = "prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:${toString prometheus.port}";
            isDefault = true;
          }
          {
            name = "Loki";
            orgId = 1;
            uid = "loki";
            type = "loki";
            access = "proxy";
            url = "http://${centralHost.network.lan.ipv4.host}:${toString loki.port}";
          }
        ];
      };
    };
  };

  systemd.services.grafana-datasource-repair = {
    description = "One-time Grafana datasource UID repair";
    before = [ "grafana.service" ];
    wantedBy = [ "grafana.service" ];
    path = [ pkgs.sqlite ];
    serviceConfig = {
      Type = "oneshot";
      User = "grafana";
      Group = "grafana";
    };
    script = ''
      set -eu

      db="/var/lib/grafana/data/grafana.db"
      marker="/var/lib/grafana/data/.datasource-repair-v1.done"
      backup="/var/lib/grafana/data/grafana.db.pre-datasource-repair"

      mkdir -p /var/lib/grafana/data

      if [ -e "$marker" ]; then
        exit 0
      fi

      if [ ! -f "$db" ]; then
        touch "$marker"
        exit 0
      fi

      if [ ! -f "$backup" ]; then
        cp "$db" "$backup"
      fi

      sqlite3 "$db" "DELETE FROM data_source WHERE org_id = 1 AND name IN ('Prometheus', 'Loki');"
      touch "$marker"
    '';
  };

  systemd.services.grafana = {
    wants = [
      "grafana-datasource-repair.service"
      "sops-install-secrets.service"
      "prometheus.service"
      "loki.service"
    ];
    after = [
      "grafana-datasource-repair.service"
      "sops-install-secrets.service"
      "prometheus.service"
      "loki.service"
    ];
  };
}
