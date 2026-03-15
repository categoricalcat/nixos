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
        animate-appicon-hover = true;
        animate-appicon-hover-animation-extent = [
          (lib.hm.gvariant.mkDictionaryEntry [
            "RIPPLE"
            4
          ])
          (lib.hm.gvariant.mkDictionaryEntry [
            "PLANK"
            4
          ])
          (lib.hm.gvariant.mkDictionaryEntry [
            "SIMPLE"
            1
          ])
        ];
        appicon-margin = lib.hm.gvariant.mkUint32 4;
        appicon-padding = lib.hm.gvariant.mkUint32 4;
        appicon-style = "NORMAL";
        dot-position = "BOTTOM";
        dot-style-focused = "DASHES";
        dot-style-unfocused = "DOTS";
        extension-version = 72;
        global-border-radius = 0;
        hotkeys-overlay-combo = "TEMPORARILY";
        intellihide = false;
        multi-monitors = false;
        panel-anchors = ''{"AUS-S2LMQS085997":"MIDDLE","GSM-0x000083cb":"MIDDLE"}'';
        panel-element-positions = "{}";
        panel-lengths = ''{"AUS-S2LMQS085997":100,"GSM-0x000083cb":100}'';
        panel-positions = ''{"AUS-S2LMQS085997":"TOP","GSM-0x000083cb":"TOP"}'';
        panel-side-margins = 0;
        panel-sizes = ''{"AUS-S2LMQS085997":28,"GSM-0x000083cb":28}'';
        prefs-opened = false;
        trans-gradient-bottom-color = "#ffffff";
        trans-panel-opacity = 0.29;
        trans-use-border = false;
        trans-use-custom-bg = false;
        trans-use-custom-gradient = false;
        trans-use-custom-opacity = true;
        trans-use-dynamic-opacity = false;
        window-preview-title-position = "TOP";
      };
    };
  };
}
