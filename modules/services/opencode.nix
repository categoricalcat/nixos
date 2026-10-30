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
  opencodeConfigPath = "${opencodeConfigHome}/opencode/opencode.json";
  host = allAddresses.hosts.${config.networking.hostName};
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
        ExecStart = "${pkgs.opencode}/bin/opencode serve --port ${toString host.services.opencode.port} --hostname ${host.network.lan.ipv4.host}";
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
