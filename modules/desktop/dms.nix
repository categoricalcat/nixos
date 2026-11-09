{
  config,
  lib,
  inputs,
  ...
}:

let
  canSleep = config.systemd.targets.sleep.enable or false;
in
{
  config = lib.mkIf (config.desktop.shell == "dms") {
    home-manager.users.yi = {
      imports = [
        inputs.dms.homeModules.dank-material-shell
        ../../users/programs/dms.nix
      ]
      ++ lib.optionals (config.desktop.environment == "niri") [
        inputs.dms.homeModules.niri
        ../../users/programs/niri-dms.nix
      ];

      programs.dank-material-shell.settings = {
        lockBeforeSuspend = canSleep;
        powerMenuActions =
          if canSleep then
            [
              "reboot"
              "logout"
              "poweroff"
              "lock"
              "suspend"
              "hibernate"
              "restart"
            ]
          else
            [
              "reboot"
              "logout"
              "poweroff"
              "lock"
              "restart"
            ];
      };
    };

    services = {
      accounts-daemon.enable = true;
      printing.enable = true;

      geoclue2 = {
        enable = true;
        appConfig."dms" = {
          isAllowed = true;
          isSystem = true;
        };
      };
    };

    programs = {
      dux-search = {
        enable = true;
        systemd.target = "graphical-session.target";
      };

      dux-calendar = {
        enable = true;
        systemd.enable = true;
      };

      dux-files = {
        enable = true;
        systemd.enable = true;
        portal.enable = true;
      };
    };

    hardware.i2c.enable = true;
    users.users.yi.extraGroups = [ "i2c" ];

    # DMS provides the session agent; concurrent agents race for prompts.
    systemd.user.services.polkit-gnome-agent.enable = false;

    xdg = {
      mime.defaultApplications."inode/directory" = "dev.duxlabs.files.desktop";
      portal.config = lib.genAttrs [ "common" "niri" "mango" ] (_: {
        "org.freedesktop.impl.portal.FileChooser" = [ "dfiles" ];
      });
    };
  };
}
