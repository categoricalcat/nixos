{
  pkgs,
  lib,
  config,
  ...
}:

let
  opencodeHome = "/home/yi";
  opencodeConfigHome = "${opencodeHome}/.config";
  opencodeConfigPath = "${opencodeConfigHome}/opencode/config.json";
in
{
  options.services.opencode = {
    enable = lib.mkEnableOption "Opencode Serve daemon";
  };

  config = lib.mkIf config.services.opencode.enable {
    systemd.services.opencode = {
      description = "Opencode Serve Daemon";
      wantedBy = [ "multi-user.target" ];
      wants = [
        "network-online.target"
        "podman-mcp-searxng.service"
      ];
      after = [
        "network-online.target"
        "podman-mcp-searxng.service"
      ];

      serviceConfig = {
        ExecStart = "${pkgs.opencode}/bin/opencode serve --port 3010 --hostname 127.0.0.1";
        Restart = "on-failure";
        RestartSec = 5;
        User = "yi";
        Group = "users";
      };

      environment = {
        HOME = opencodeHome;
        XDG_CONFIG_HOME = opencodeConfigHome;
        OPENCODE_CONFIG = opencodeConfigPath;
      };
    };
  };
}
