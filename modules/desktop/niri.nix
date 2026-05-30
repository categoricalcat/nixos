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
        };
      };
    };
  };
}
