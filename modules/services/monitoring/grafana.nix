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
  postgres = services.postgresql;

  dashboardDir =
    pkgs.runCommand "grafana-dashboards"
      {
        nativeBuildInputs = [ pkgs.jq ];
      }
      ''
        mkdir -p $out

        # Process vendored JSON dashboards (strip .id/__inputs, resolve
        # the DS_PROMETHEUS datasource placeholders to the provisioned uid)
        for f in ${./dashboards/vendor}/*.json; do
          if [ -f "$f" ]; then
            jq '
              del(.id, .__inputs) |
              del(.templating.list[]? | select(.name == "DS_PROMETHEUS")) |
              walk(
                if type == "object" then
                  if .datasource? == "''${DS_PROMETHEUS}" then
                    .datasource = { type: "prometheus", uid: "prometheus" }
                  elif (.datasource? | type) == "object" and .datasource.uid == "''${DS_PROMETHEUS}" then
                    .datasource.uid = "prometheus"
                  else
                    .
                  end
                else
                  .
                end
              ) |
              walk(
                if type == "object" and has("type") and .type == "query" and has("name") then
                  .includeAll = false | .multi = false
                else
                  .
                end
              ) |
              walk(
                if type == "object" and .legend?.placement? == "right" then
                  .legend.placement = "bottom"
                else
                  .
                end
              )
            ' "$f" > "$out/$(basename "$f")"
          fi
        done

        # Custom Nix dashboards
        ln -s ${
          pkgs.writeText "systemd-units.json" (
            builtins.toJSON (import ./dashboards/systemd-units.nix { inherit pkgs; })
          )
        } $out/systemd-units.json
        ln -s ${
          pkgs.writeText "services-overview.json" (
            builtins.toJSON (import ./dashboards/services-overview.nix { inherit pkgs; })
          )
        } $out/services-overview.json
        ln -s ${
          pkgs.writeText "fail2ban.json" (
            builtins.toJSON (import ./dashboards/fail2ban.nix { inherit pkgs; })
          )
        } $out/fail2ban.json
        ln -s ${
          pkgs.writeText "prometheus.json" (
            builtins.toJSON (import ./dashboards/prometheus.nix { inherit pkgs; })
          )
        } $out/prometheus.json
        ln -s ${
          pkgs.writeText "loki.json" (builtins.toJSON (import ./dashboards/loki.nix { inherit pkgs; }))
        } $out/loki.json
        ln -s ${
          pkgs.writeText "grafana.json" (builtins.toJSON (import ./dashboards/grafana.nix { inherit pkgs; }))
        } $out/grafana.json
        ln -s ${
          pkgs.writeText "postgres.json" (
            builtins.toJSON (import ./dashboards/postgres.nix { inherit pkgs; })
          )
        } $out/postgres.json
        ln -s ${
          pkgs.writeText "valkey.json" (builtins.toJSON (import ./dashboards/valkey.nix { inherit pkgs; }))
        } $out/valkey.json
      '';
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

      database = {
        type = "postgres";
        host = postgres.socketDir;
        name = postgres.databases.grafana;
        user = postgres.databases.grafana;
      };
    };

    provision = {
      enable = true;
      dashboards.settings.providers = [
        {
          name = "declarative";
          options.path = dashboardDir;
          disableDeletion = false;
          foldersFromFilesStructure = false;
        }
      ];
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

  systemd.services.grafana = {
    wants = [
      "sops-install-secrets.service"
      "prometheus.service"
      "loki.service"
    ];
    after = [
      "sops-install-secrets.service"
      "prometheus.service"
      "loki.service"
    ];
  };
}
