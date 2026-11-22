{
  pkgs,
  lib,
  config,
  allAddresses,
  systemdHardening,
  ...
}:

let
  opencodeHome = config.users.users.yi.home;
  opencodeConfigHome = "${opencodeHome}/.config";
  opencodeConfigPath = "${opencodeConfigHome}/opencode/opencode.json";
  host = allAddresses.hosts.${config.networking.hostName};
in
{
  options.services.opencode = {
    enable = lib.mkEnableOption "Opencode Serve daemon";
  };

  config = lib.mkIf config.services.opencode.enable {
    sops.secrets."passwords/opencode" = { };
    sops.templates."opencode.env".content = ''
      OPENCODE_PASSWORD=${config.sops.placeholder."passwords/opencode"}
    '';

    systemd.services.opencode = {
      description = "Opencode Serve Daemon";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      # The unit runs as yi but only sees the system PATH, not the user
      # profile, so the search tools the agent policies rely on are pinned here.
      path = [
        pkgs.fd
        pkgs.ripgrep
        pkgs.jq
        pkgs.curl
        pkgs.git
      ];

      # HM activation relinks opencode.json without changing this unit, so a
      # switch never restarts the daemon and it serves stale config. Restart
      # whenever the opencode settings change.
      restartTriggers = [
        (builtins.toJSON config.home-manager.users.yi.programs.opencode.settings)
      ];

      # The agent's job is running arbitrary user commands in home dirs: no
      # ProtectHome, ProtectSystem stays full (not strict), and bun's JIT,
      # spawned PTYs and sandboxed tools need the relaxed entries removed.
      serviceConfig =
        removeAttrs systemdHardening [
          "MemoryDenyWriteExecute"
          "ProtectHome"
          "PrivateDevices"
          "RestrictNamespaces"
        ]
        // {
          ProtectSystem = "full";
          EnvironmentFile = config.sops.templates."opencode.env".path;
          ExecStart = "${pkgs.opencode}/bin/opencode serve --port ${toString host.services.opencode.port} --hostname 127.0.0.1";
          Restart = "on-failure";
          RestartSec = 5;
          User = "yi";
          Group = "yi";
        };

      environment = {
        HOME = opencodeHome;
        OPENCODE_ENABLE_EXA = "0";
        XDG_CONFIG_HOME = opencodeConfigHome;
        OPENCODE_CONFIG = opencodeConfigPath;
      };
    };
  };
}
