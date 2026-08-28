{
  pkgs,
  lib,
  config,
  ...
}:

let
  extensions = import ./extensions.nix { inherit pkgs; };
in
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

    home-manager.sharedModules = [ ./home.nix ];

    environment.systemPackages =
      (with pkgs; [
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
      ])
      ++ extensions;
  };
}
