{
  allAddresses,
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.security-monitor;
  monitoringLib = import ../lib.nix;
  nodeTextfileDir = allAddresses.monitoring.nodeTextfileDir;
  cacheDirs = {
    vulnix = "/var/cache/vulnix";
    trivy = "/var/cache/trivy";
  };
  oneshotServiceConfig = {
    Type = "oneshot";
    PrivateTmp = true;
    ProtectSystem = "strict";
    ProtectHome = true;
  };

  fastAuditScript = pkgs.writeShellApplication {
    name = "security-audit-fast";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.jq
      config.systemd.package
    ];
    text = ''
      exec ${pkgs.bash}/bin/bash ${./scripts/system-audit.sh} "${nodeTextfileDir}"
    '';
  };

  # Commit per NVD archive: one stalled feed otherwise aborts the whole import and leaves the DB empty
  vulnixPatched = pkgs.vulnix.overridePythonAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/vulnix/nvd.py \
        --replace-fail "timeout=10" "timeout=120" \
        --replace-fail "self.add(arch)" "self.add(arch); transaction.commit()"
    '';
  });

  cveScanScript = pkgs.writeShellApplication {
    name = "security-audit-cve";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.findutils
      pkgs.jq
      vulnixPatched
      config.nix.package
    ]
    ++ lib.optionals cfg.cveScan.scanContainers [
      pkgs.trivy
      pkgs.podman
    ];
    text = ''
      exec ${pkgs.bash}/bin/bash ${./scripts/cve-scan.sh} \
        --textfile-dir "${nodeTextfileDir}" \
        ${
          lib.optionalString (
            cfg.cveScan.whitelistFile != null
          ) "--whitelist-file \"${cfg.cveScan.whitelistFile}\""
        } \
        ${lib.optionalString cfg.cveScan.scanContainers "--scan-containers"} \
        ${lib.optionalString (
          cfg.cveScan.scanContainers && cfg.cveScan.containerImages != [ ]
        ) "-- ${lib.concatStringsSep " " (map lib.escapeShellArg cfg.cveScan.containerImages)}"}
    '';
  };

in
{
  options.services.security-monitor = {
    enable = lib.mkEnableOption "Security and vulnerability monitoring textfile exporter";

    fastAudit = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable fast security audit (kernel drift, systemd exposure)";
      };
      interval = lib.mkOption {
        type = lib.types.str;
        default = "15m";
        description = "Interval for fast security audit timer";
      };
    };

    cveScan = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable deep CVE scanning via Vulnix and Trivy";
      };
      calendar = lib.mkOption {
        type = lib.types.str;
        default = config.yi.maintenance.slots.cveScan.calendar;
        description = "Systemd OnCalendar expression for deep CVE scan";
      };
      randomizedDelay = lib.mkOption {
        type = lib.types.str;
        default = config.yi.maintenance.slots.cveScan.jitter;
        description = "Randomized delay for deep CVE scan timer";
      };
      scanContainers = lib.mkOption {
        type = lib.types.bool;
        default = config.networking.hostName == allAddresses.monitoring.centralHost;
        description = "Whether to scan Podman container images with Trivy";
      };
      containerImages = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = lib.pipe (config.virtualisation.oci-containers.containers or { }) [
          (lib.filterAttrs (
            _: c: c.imageFile == null && c.imageStream == null && !lib.hasPrefix "localhost/" c.image
          ))
          (lib.mapAttrsToList (_: c: c.image))
          lib.unique
        ];
        description = "Registry container images to scan if container scanning is enabled (Nix-built images are covered by vulnix)";
      };
      whitelistFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = ./vulnix-whitelist.toml;
        description = "TOML whitelist file passed to vulnix -w (null disables it)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd = {
      tmpfiles.rules = [
        "d ${nodeTextfileDir} 0755 root root - -"
        "d ${cacheDirs.vulnix} 0755 root root - -"
      ]
      ++ lib.optional cfg.cveScan.scanContainers "d ${cacheDirs.trivy} 0755 root root - -";

      services = {
        security-audit-fast = lib.mkIf cfg.fastAudit.enable {
          description = "Fast Security Audit (Systemd Hardening, Kernel Drift)";
          serviceConfig = oneshotServiceConfig // {
            ExecStart = "${fastAuditScript}/bin/security-audit-fast";
            PrivateNetwork = true;
            NoNewPrivileges = true;
            ReadWritePaths = [ nodeTextfileDir ];
            TimeoutStartSec = "120s";
          };
        };

        security-audit-cve = lib.mkIf cfg.cveScan.enable (
          monitoringLib.mkWantsAfter [ "network-online.target" ]
          // {
            description = "Deep CVE Vulnerability Scan (Vulnix & Trivy)";
            environment = {
              NIX_REMOTE = "daemon";
            }
            // lib.optionalAttrs cfg.cveScan.scanContainers {
              TMPDIR = cacheDirs.trivy;
              DOCKER_HOST = "unix:///run/podman/podman.sock";
            };
            serviceConfig = oneshotServiceConfig // {
              ExecStart = "${cveScanScript}/bin/security-audit-cve";
              PrivateNetwork = false;
              ReadWritePaths = [
                cacheDirs.vulnix
                nodeTextfileDir
                "/tmp"
              ]
              ++ lib.optional cfg.cveScan.scanContainers cacheDirs.trivy;
              TimeoutStartSec = "1800s";
            };
          }
        );
      };

      timers = {
        security-audit-fast = lib.mkIf cfg.fastAudit.enable {
          description = "Trigger fast security audit";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "1m";
            OnUnitActiveSec = cfg.fastAudit.interval;
          };
        };

        security-audit-cve = lib.mkIf cfg.cveScan.enable {
          description = "Trigger deep CVE vulnerability scan";
          wantedBy = [ "timers.target" ];
          timerConfig = config.yi.maintenance.slots.cveScan.timerConfig // {
            OnCalendar = cfg.cveScan.calendar;
            RandomizedDelaySec = cfg.cveScan.randomizedDelay;
            Persistent = true;
          };
        };
      };
    };
  };
}
