{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.services.opencode = {
    enable = lib.mkEnableOption "Opencode Serve daemon";
  };

  config = lib.mkIf config.services.opencode.enable {
    systemd.services.opencode = {
      description = "Opencode Serve Daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.opencode}/bin/opencode serve --port 3010 --hostname 127.0.0.1";
        Restart = "on-failure";
        RestartSec = 5;
        User = "yi";
        Group = "users";
      };

      environment = {
        SEARXNG_URL = "http://127.0.0.1:8888";
      };
    };
  };
}
