{
  pkgs,
  lib,
  config,
  allAddresses,
  ...
}:

let
  opencodeHome = config.users.users.yi.home;
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
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.opencode}/bin/opencode serve --port ${
          toString allAddresses.hosts.${config.networking.hostName}.services.opencode.port
        } --hostname 0.0.0.0";
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
