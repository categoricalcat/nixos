{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkMerge [
    (lib.mkIf (config.desktop.shell == "dms") {
      services.accounts-daemon.enable = true;

      services.geoclue2 = {
        enable = true;
        appConfig."dms" = {
          isAllowed = true;
          isSystem = true;
        };
      };

      programs.dsearch = {
        enable = true;
        systemd.target = "graphical-session.target";
      };

      environment.systemPackages = with pkgs; [
        brightnessctl
        cups-pk-helper
      ];
    })
  ];
}
