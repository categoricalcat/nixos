{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib;
  dashLib = import ./lib.nix { inherit lib; };
in
dashLib.mkDashboard {
  uid = "security";
  title = "Security & Vulnerabilities";
  panels = [
    # --- Header KPI Row ---
    (dashLib.mkStat {
      title = "Critical CVEs";
      expr = "sum(node_security_vulnerabilities_total{severity=\"CRITICAL\"}) by (host)";
      gridPos = dashLib.mkGridPos 0 0 4 4;
      legendFormat = "{{host}}";
      thresholds = [
        {
          color = "green";
          value = null;
        }
        {
          color = "red";
          value = 1;
        }
      ];
    })
    (dashLib.mkStat {
      title = "High CVEs";
      expr = "sum(node_security_vulnerabilities_total{severity=\"HIGH\"}) by (host)";
      gridPos = dashLib.mkGridPos 4 0 4 4;
      legendFormat = "{{host}}";
      thresholds = [
        {
          color = "green";
          value = null;
        }
        {
          color = "orange";
          value = 1;
        }
      ];
    })
    (dashLib.mkStat {
      title = "Kernel Reboot Status";
      expr = "node_security_reboot_required";
      gridPos = dashLib.mkGridPos 8 0 4 4;
      legendFormat = "{{host}}";
      mappings = [
        {
          type = "value";
          options = {
            "0" = {
              text = "Clean";
              color = "green";
            };
            "1" = {
              text = "Reboot Required";
              color = "red";
            };
          };
        }
      ];
      thresholds = [
        {
          color = "green";
          value = null;
        }
        {
          color = "red";
          value = 1;
        }
      ];
    })
    (dashLib.mkStat {
      title = "System Generation Age";
      expr = "node_security_generation_age_seconds / 86400";
      gridPos = dashLib.mkGridPos 12 0 4 4;
      legendFormat = "{{host}}";
      unit = "d";
      thresholds = [
        {
          color = "green";
          value = null;
        }
        {
          color = "orange";
          value = 14;
        }
        {
          color = "red";
          value = 30;
        }
      ];
    })
    (dashLib.mkStat {
      title = "Unsafe Systemd Services";
      expr = "sum(node_systemd_units_by_status_total{status=\"UNSAFE\"}) by (host)";
      gridPos = dashLib.mkGridPos 16 0 4 4;
      legendFormat = "{{host}}";
      thresholds = [
        {
          color = "green";
          value = null;
        }
        {
          color = "red";
          value = 1;
        }
      ];
    })
    (dashLib.mkStat {
      title = "Active Fail2ban Bans";
      expr = "sum(f2b_jail_banned_current) by (host)";
      gridPos = dashLib.mkGridPos 20 0 4 4;
      legendFormat = "{{host}}";
      thresholds = [
        {
          color = "green";
          value = null;
        }
        {
          color = "orange";
          value = 1;
        }
        {
          color = "red";
          value = 10;
        }
      ];
    })

    # --- Vulnerability Breakdown Row ---
    (dashLib.mkTimeseries {
      title = "Vulnerabilities by Severity & Target";
      expr = "node_security_vulnerabilities_total";
      gridPos = dashLib.mkGridPos 0 4 10 8;
      legendFormat = "{{host}} {{target}} {{severity}}";
    })
    (dashLib.mkTable {
      title = "Vulnerable Packages (Critical & High)";
      expr = "node_security_vulnerable_package_info == 1";
      gridPos = dashLib.mkGridPos 10 4 14 8;
      transformations = [
        {
          id = "organize";
          options = {
            excludeByName = {
              Time = true;
              Value = true;
              "__name__" = true;
              job = true;
              instance = true;
            };
            renameByName = {
              cve = "CVE";
              package = "Package";
              severity = "Severity";
              target = "Target";
              host = "Host";
            };
          };
        }
      ];
      overrides = [
        {
          matcher = {
            id = "byName";
            options = "Severity";
          };
          properties = [
            {
              id = "custom.cellOptions";
              value = {
                type = "color-text";
              };
            }
            {
              id = "mappings";
              value = [
                {
                  type = "value";
                  options = {
                    "CRITICAL" = {
                      color = "red";
                      text = "CRITICAL";
                    };
                    "HIGH" = {
                      color = "orange";
                      text = "HIGH";
                    };
                    "MEDIUM" = {
                      color = "yellow";
                      text = "MEDIUM";
                    };
                    "LOW" = {
                      color = "blue";
                      text = "LOW";
                    };
                  };
                }
              ];
            }
          ];
        }
      ];
    })

    # --- Service Hardening Row ---
    (dashLib.mkBarGauge {
      title = "Top Systemd Service Exposure Scores (0.0 Safe - 10.0 Unsafe)";
      expr = "topk(25, node_systemd_unit_exposure_score)";
      gridPos = dashLib.mkGridPos 0 12 14 10;
      legendFormat = "{{host}} {{name}}";
      unit = "none";
      min = 0;
      max = 10;
      thresholds = [
        {
          color = "green";
          value = null;
        }
        {
          color = "orange";
          value = 4.0;
        }
        {
          color = "red";
          value = 7.0;
        }
      ];
      links = [
        (dashLib.mkLokiDataLink {
          title = "View logs in Loki for unsafe unit";
        })
      ];
    })
    (dashLib.mkTimeseries {
      title = "Systemd Units by Security Predicate";
      expr = "node_systemd_units_by_status_total";
      gridPos = dashLib.mkGridPos 14 12 10 10;
      legendFormat = "{{host}} {{status}}";
    })

    # --- Auth & Intrusion Row ---
    (dashLib.mkTimeseries {
      title = "SSH / Auth Failure Rate";
      expr = "sum(rate(f2b_jail_failed_total[15m])) by (host, jail)";
      gridPos = dashLib.mkGridPos 0 22 12 8;
      legendFormat = "{{host}} {{jail}} failures/s";
    })
    (dashLib.mkTimeseries {
      title = "Fail2ban Ban Activity by Jail";
      expr = "f2b_jail_banned_current";
      gridPos = dashLib.mkGridPos 12 22 12 8;
      legendFormat = "{{host}} {{jail}}";
    })
  ];
}
