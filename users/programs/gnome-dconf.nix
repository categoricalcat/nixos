{ lib, pkgs, ... }:

{
  dconf = {
    enable = true;
    settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = with pkgs.gnomeExtensions; [
          appindicator.extensionUuid
          dash-to-panel.extensionUuid
          arcmenu.extensionUuid
          gtile.extensionUuid
          weather-oclock.extensionUuid
        ];

        favorite-apps = [
          "floorp.desktop"
          "google-chrome.desktop"
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
        experimental-features = [
          "scale-monitor-framebuffer"
          "xwayland-native-scaling"
        ];
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

      "org/gnome/shell/extensions/dash-to-panel" = {
        panel-positions = ''{"0":"TOP"}'';
        panel-sizes = ''{"0":32}'';
        appicon-margin = lib.hm.gvariant.mkUint32 4;
        dot-style-focused = "DASHES";
        dot-style-unfocused = "DOTS";
      };

      "org/gnome/shell/extensions/arcmenu" = {
        menu-button-appearance = "Icon";
        menu-layout = "Default";
      };
    };
  };
}
