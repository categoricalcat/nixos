{
  config,
  lib,
  pkgs,
  ...
}:

let
  colors = import ../theme.nix;
  styl = config.stylix;
  isDark = styl.polarity == "dark";

  swayConfig = pkgs.writeText "regreet-sway.conf" ''
    output * bg ${styl.image} fill
    seat * xcursor_theme ${styl.cursor.name} ${toString styl.cursor.size}
    default_border none
    default_floating_border none
    exec "${lib.getExe config.programs.regreet.package}; swaymsg exit"
  '';
in
{
  config = lib.mkIf (config.desktop.greeter == "regreet") {
    services.accounts-daemon.enable = true;

    # Disable Stylix's regreet target so it doesn't warn about our sway-based
    # greetd command. We pull the same values from Stylix manually below.
    stylix.targets.regreet.enable = false;

    programs.regreet = {
      enable = true;

      theme = {
        package = pkgs.adw-gtk3;
        name = if isDark then "adw-gtk3-dark" else "adw-gtk3";
      };

      iconTheme = {
        inherit (styl.icons) package;
        name = if isDark then styl.icons.dark else styl.icons.light;
      };

      cursorTheme = {
        inherit (styl.cursor) package name;
      };

      font = {
        inherit (styl.fonts.sansSerif) package name;
      };

      settings = {
        GTK.application_prefer_dark_theme = isDark;

        appearance.greeting_msg = config.desktop.greeting;

        commands = {
          reboot = [
            "systemctl"
            "reboot"
          ];
          poweroff = [
            "systemctl"
            "poweroff"
          ];
        };
      };

      extraCss = ''
        @define-color accent_color #${colors.base0E};
        @define-color accent_bg_color #${colors.base02};
        @define-color accent_fg_color #${colors.base05};
        @define-color destructive_color #${colors.base08};
        @define-color destructive_bg_color #${colors.base02};
        @define-color destructive_fg_color #${colors.base05};
        @define-color success_color #${colors.base0B};
        @define-color success_bg_color #${colors.base02};
        @define-color success_fg_color #${colors.base05};
        @define-color warning_color #${colors.base09};
        @define-color warning_bg_color #${colors.base02};
        @define-color warning_fg_color #${colors.base05};
        @define-color error_color #${colors.base08};
        @define-color error_bg_color #${colors.base02};
        @define-color error_fg_color #${colors.base05};
        @define-color window_bg_color #${colors.base00};
        @define-color window_fg_color #${colors.base05};
        @define-color view_bg_color #${colors.base01};
        @define-color view_fg_color #${colors.base05};
        @define-color headerbar_bg_color #${colors.base00};
        @define-color headerbar_fg_color #${colors.base05};
        @define-color sidebar_bg_color #${colors.base01};
        @define-color sidebar_fg_color #${colors.base05};
        @define-color card_bg_color #${colors.base01};
        @define-color card_fg_color #${colors.base05};
        @define-color popover_bg_color #${colors.base01};
        @define-color popover_fg_color #${colors.base05};

        * {
          color: #${colors.base05};
          caret-color: #${colors.base05};
        }

        window { background: transparent; }

        box,
        grid {
          background-color: #${colors.base00};
          border-radius: 16px;
        }

        entry,
        dropdown,
        button { border-radius: 10px; }

        entry:focus,
        dropdown:focus,
        button:focus {
          box-shadow: 0 0 0 2px alpha(@window_fg_color, 0.25);
        }
      '';
    };

    services.greetd = {
      enable = true;
      settings.default_session = {
        user = "greeter";
        command = "${pkgs.dbus}/bin/dbus-run-session ${lib.getExe pkgs.sway} --config ${swayConfig}";
      };
    };

    systemd.services.greetd.environment = {
      GTK_THEME = config.programs.regreet.theme.name;
      XCURSOR_THEME = styl.cursor.name;

      GDK_DEBUG = "no-portals";
      XDG_CURRENT_DESKTOP = "sway";
      GSK_RENDERER = "ngl";
      NO_AT_BRIDGE = "1";
    };
  };
}
