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

    environment.systemPackages = with pkgs; [
      dconf2nix
      dconf-editor

      gnomeExtensions.appindicator
      gnomeExtensions.clipboard-indicator
      gnomeExtensions.dash-to-panel
      gnomeExtensions.gtile
      gnomeExtensions.kimpanel
      gnomeExtensions.pip-on-top
      gnomeExtensions.vitals
      gnomeExtensions.openmeteoweather
      gnomeExtensions.vertical-workspaces
      gnomeExtensions.mpris-label
      gnomeExtensions.tiling-assistant
      gnomeExtensions.impatience
    ];

    home-manager.sharedModules = [ ./gnome-home.nix ];
  };
}
