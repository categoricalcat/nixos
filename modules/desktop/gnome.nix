{
  pkgs,
  lib,
  config,
  ...
}:

{
  config = lib.mkIf (config.desktop.environment == "gnome") {
    services = {
      xserver.enable = true;

      desktopManager = {
        gnome = {
          enable = true;
        };
      };

      displayManager = {
        gdm = {
          enable = config.desktop.greeter == "gdm";
          banner = config.desktop.greeting;
        };
      };

      gnome = {
        core-apps.enable = false;
        core-developer-tools.enable = false;
        games.enable = false;
      };

      geoclue2 = {
        enable = true;
        appConfig."gnome-shell" = {
          isAllowed = true;
          isSystem = true;
          users = [ "1000" ];
        };
        appConfig."org.gnome.Weather" = {
          isAllowed = true;
          isSystem = true;
          users = [ "1000" ];
        };
      };

      input-remapper = {
        enable = false;
      };
    };

    systemd.user.services."org.freedesktop.IBus.session.GNOME".enable = false;

    environment.gnome.excludePackages = with pkgs; [
      gnome-tour
      gnome-user-docs
    ];

    home-manager.sharedModules = [ ./gnome-home.nix ];

    environment.systemPackages = with pkgs; [
      dconf2nix
      dconf-editor

      loupe
      nautilus
      showtime
      snapshot
      decibels
      gnome-weather
      gnome-calendar
      gnome-calculator
      gnome-disk-utility
      gnome-system-monitor

      gnomeExtensions.vitals
      # gnomeExtensions.gtile
      gnomeExtensions.kimpanel
      # gnomeExtensions.paperwm
      gnomeExtensions.pip-on-top
      gnomeExtensions.impatience
      gnomeExtensions.user-themes
      (gnomeExtensions.mpris-label.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace players.js \
            --replace-fail "import Gio from 'gi://Gio';" "import Gio from 'gi://Gio'; import GioUnix from 'gi://GioUnix';" \
            --replace-fail "Gio.DesktopAppInfo" "GioUnix.DesktopAppInfo"
        '';
      }))
      (gnomeExtensions.appindicator.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace trayIconsManager.js \
            --replace-fail "Util.Logger.warning" "Util.Logger.warn"
        '';
      }))
      gnomeExtensions.dash-to-panel
      gnomeExtensions.weather-oclock
      # this bitch crashing: gnomeExtensions.tiling-assistant
      gnomeExtensions.clipboard-indicator
      gnomeExtensions.vertical-workspaces
      gnomeExtensions.switch-workspaces-on-active-monitor
    ];

  };
}
