{
  allAddresses,
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.services.prometheus.exporters.adguard;
  adguard-exporter = pkgs.callPackage ./package.nix { };
  aghUrl = "http://127.0.0.1:${
    toString allAddresses.hosts.${config.networking.hostName}.services.adguardhome.port
  }";
in
{
  options.services.prometheus.exporters.adguard = mkOption {
    type = types.submodule {
      options = {
        enable = mkEnableOption "the prometheus adguard exporter";
        port = mkOption {
          type = types.port;
          default = 9617;
          description = "Port to listen on.";
        };
        listenAddress = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = ''
            Address to listen on. Kept for framework compatibility; the
            exporter binary binds all interfaces regardless.
          '';
        };
        openFirewall = mkOption {
          type = types.bool;
          default = false;
          description = "Open port in firewall for incoming connections.";
        };
        scrapeInterval = mkOption {
          type = types.str;
          default = "15";
          description = "AdGuard API scrape interval in seconds.";
        };
        adguardUser = mkOption {
          type = types.str;
          default = "admin";
          description = "AdGuard Home API username (dummy while auth is disabled).";
        };
        adguardPass = mkOption {
          type = types.str;
          default = "none";
          description = "AdGuard Home API password (dummy while auth is disabled).";
        };
      };
    };
    default = { };
    description = "Prometheus AdGuard Home exporter configuration.";
  };

  config = mkIf cfg.enable {
    systemd.services.prometheus-adguard-exporter = {
      description = "Prometheus AdGuard Home exporter";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "adguardhome.service"
      ];
      wants = [ "adguardhome.service" ];

      environment = {
        ADGUARD_HOST = aghUrl;
        ADGUARD_USER = cfg.adguardUser;
        ADGUARD_PASS = cfg.adguardPass;
        EXPORTER_PORT = toString cfg.port;
        SCRAPE_INTERVAL = cfg.scrapeInterval;
        LOG_LEVEL = "WARN";
      };

      serviceConfig = {
        ExecStart = "${adguard-exporter}/bin/adguardexporter";
        Restart = "always";
        DynamicUser = true;
        WorkingDirectory = "/";
        PrivateTmp = true;
        # Hardening
        CapabilityBoundingSet = [ "" ];
        DeviceAllow = [ "" ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
      };
    };
  };
}
