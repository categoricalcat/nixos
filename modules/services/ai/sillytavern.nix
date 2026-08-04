{
  config,
  lib,
  pkgs,
  allAddresses,
  ...
}:

let
  yifuwuqiServices = allAddresses.hosts.yifuwuqi.services;
  cfg = config.yi.services.sillytavern;
in
{
  options.yi.services.sillytavern = {
    enable = lib.mkEnableOption "SillyTavern local AI companion";
  };

  config = lib.mkIf cfg.enable {
    users.users.sillytavern = {
      isSystemUser = true;
      group = "sillytavern";
    };
    users.groups.sillytavern = { };

    systemd.services.sillytavern = {
      description = "Silly Tavern";
      after = [
        "network.target"
        "llama-cpp-qwen3-6-35b-abliterated.service"
      ];
      wants = [ "llama-cpp-qwen3-6-35b-abliterated.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        HOME = "/var/lib/SillyTavern";
        XDG_DATA_HOME = "/var/lib";
      };

      preStart = ''
        if [ -L /var/lib/SillyTavern/config.yaml ]; then
          rm -f /var/lib/SillyTavern/config.yaml
        fi

        # Ensure config.yaml exists before modifying
        if [ ! -f /var/lib/SillyTavern/config.yaml ]; then
          # Start and immediately kill to generate default config
          ${pkgs.sillytavern}/bin/sillytavern --port=${toString yifuwuqiServices.sillytavern.port} &
          ST_PID=$!
          sleep 3
          kill $ST_PID || true
        fi

        # Force securityOverride to bypass listen 0.0.0.0 crash when whitelisting is disabled
        if grep -q "securityOverride:" /var/lib/SillyTavern/config.yaml; then
          ${pkgs.gnused}/bin/sed -i 's/^securityOverride:.*/securityOverride: true/' /var/lib/SillyTavern/config.yaml
        else
          echo "securityOverride: true" >> /var/lib/SillyTavern/config.yaml
        fi
      '';

      serviceConfig = {
        ExecStart = "${pkgs.sillytavern}/bin/sillytavern --port=${toString yifuwuqiServices.sillytavern.port} --listen=true --no-whitelist";
        User = "sillytavern";
        Group = "sillytavern";
        StateDirectory = "SillyTavern";
        WorkingDirectory = "/var/lib/SillyTavern";

        # Hardening
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        Restart = "always";
        Type = "simple";
      };
    };

    networking.firewall.allowedTCPPorts = [ yifuwuqiServices.sillytavern.port ];
  };
}
