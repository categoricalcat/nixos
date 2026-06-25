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

      input-remapper.enable = true;
    };

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
      gnomeExtensions.mpris-label
      gnomeExtensions.appindicator
      gnomeExtensions.dash-to-panel
      gnomeExtensions.weather-oclock
      # gnomeExtensions.tiling-assistant
      gnomeExtensions.clipboard-indicator
      # gnomeExtensions.vertical-workspaces
      gnomeExtensions.switch-workspaces-on-active-monitor
    ];

  };
}
