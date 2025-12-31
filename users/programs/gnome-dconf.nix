{ lib, pkgs, ... }:

{
  dconf = {
    enable = true;
    settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = with pkgs.gnomeExtensions; [
          appindicator.extensionUuid
          gtile.extensionUuid
          weather-oclock.extensionUuid
        ];

        favorite-apps = [
          "chromium.desktop"
          "org.gnome.Nautilus.desktop"
          "org.gnome.Console.desktop"
        ];
      };

      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        show-battery-percentage = true;
        clock-show-date = true;
        clock-show-weekday = true;
        enable-animations = false;
      };

      "org/gnome/desktop/wm/preferences" = {
        button-layout = "appmenu:minimize,maximize,close";
      };

      "org/gnome/mutter" = {
        center-new-windows = true;
      };

      # Input and touchpad
      "org/gnome/desktop/peripherals/touchpad" = {
        tap-to-click = true;
        natural-scroll = true;
        click-method = "fingers";
      };

      # Night Light
      "org/gnome/settings-daemon/plugins/color" = {
        night-light-enabled = false;
        night-light-schedule-automatic = true;
        night-light-temperature = lib.hm.gvariant.mkUint32 3700;
      };

      # Dash to Dock configuration
      "org/gnome/shell/extensions/dash-to-dock" = {
        dock-position = "LEFT";
        dash-max-icon-size = lib.hm.gvariant.mkUint32 32;
        intellihide = true;
        click-action = "minimize";
        transparency-mode = "FIXED";
        background-opacity = 0.3;
        trash-icon-visible = false;
        applications-icon-visible = false;
      };
    };
  };
}
