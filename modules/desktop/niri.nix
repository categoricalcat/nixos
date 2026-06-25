{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

{
  config = lib.mkIf (config.desktop.environment == "niri") {
    environment.systemPackages = with pkgs; [
      gnome-screenshot
      awww
      xwayland-satellite
      inputs.niri-float-sticky.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    programs.niri.enable = true;

    services.accounts-daemon.enable = true;

    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-gnome
      ];
      config = {
        common = {
          default = [ "gtk" ];
          "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
          "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
        };
        niri = {
          default = [
            "gnome"
            "gtk"
          ];
          "org.freedesktop.impl.portal.Access" = [ "gtk" ];
          "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
          "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
          "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        };
      };
    };

    systemd.user.services = {
      xdg-desktop-portal = {
        after = [ "xdg-desktop-autostart.target" ];
      };
      xdg-desktop-portal-gtk = {
        after = [ "xdg-desktop-autostart.target" ];
      };
      xdg-desktop-portal-gnome = {
        environment = {
          XDG_CURRENT_DESKTOP = "GNOME";
        };
        after = [ "xdg-desktop-autostart.target" ];
      };
      niri-flake-polkit = {
        after = [ "xdg-desktop-autostart.target" ];
      };
    };
  };
}
