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
          wayland = true;
        };
      };

      gnome = {
        core-apps.enable = true;
        core-developer-tools.enable = false;
        games.enable = false;
      };
    };

    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-gtk
      ];
      config = {
        common = {
          default = [
            "gnome"
            "gtk"
          ];
          "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
          "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
          "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
        };
      };
    };

    environment.gnome.excludePackages = with pkgs; [
      gnome-tour
      gnome-user-docs
    ];

    environment.sessionVariables = {
      GNOME_SHELL_SLOWDOWN_FACTOR = "0.1";
      QT_IM_MODULE = "fcitx";
      QT_IM_MODULES = "wayland;fcitx";
    };

    environment.systemPackages = with pkgs; [
      dconf2nix
      dconf-editor

      gnomeExtensions.appindicator
      gnomeExtensions.clipboard-indicator
      gnomeExtensions.dash-to-panel
      gnomeExtensions.gtile
      gnomeExtensions.kimpanel
      gnomeExtensions.media-controls
      gnomeExtensions.pip-on-top
      gnomeExtensions.vertical-workspaces
      gnomeExtensions.vitals
      gnomeExtensions.weather-oclock
    ];

    home-manager.sharedModules = [ ./gnome-home.nix ];
  };
}
