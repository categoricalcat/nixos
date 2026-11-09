{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  niriSpicy = pkgs.callPackage ../../packages/niri-spicy.nix {
    niri-spicy = inputs.niri-spicy.packages.${system}.niri;
    inherit (inputs) smithay-spicy;
  };
in
{

  config = lib.mkIf (config.desktop.environment == "niri") {
    home-manager.users.yi.imports = [
      # ../../users/programs/noctalia
      ../../users/programs/niri.nix
    ];

    environment.systemPackages = with pkgs; [
      gnome-screenshot
      awww
      xwayland-satellite
      inputs.niri-float-sticky.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    programs.niri.enable = true;
    programs.niri.package =
      if config.desktop.hdr then
        niriSpicy
      else
        inputs.niri-unstable.packages.${system}.niri.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ../../packages/niri-focus-delay.patch
          ];
        });

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
          "org.freedesktop.impl.portal.FileChooser" = lib.mkDefault [ "gtk" ];
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
    };
  };
}
