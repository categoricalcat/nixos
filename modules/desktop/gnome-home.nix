{ lib, pkgs, ... }:

let
  panelElements = [
    {
      element = "showAppsButton";
      visible = true;
      position = "stackedTL";
    }
    {
      element = "activitiesButton";
      visible = false;
      position = "stackedTL";
    }
    {
      element = "leftBox";
      visible = true;
      position = "stackedTL";
    }
    {
      element = "taskbar";
      visible = true;
      position = "stackedTL";
    }
    {
      element = "centerBox";
      visible = true;
      position = "centerMonitor";
    }
    {
      element = "dateMenu";
      visible = true;
      position = "centerMonitor";
    }
    {
      element = "rightBox";
      visible = true;
      position = "stackedBR";
    }
    {
      element = "systemMenu";
      visible = true;
      position = "stackedBR";
    }
    {
      element = "desktopButton";
      visible = false;
      position = "stackedBR";
    }
  ];
in

{
  dconf = {
    enable = true;
    settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = with pkgs.gnomeExtensions; [
          appindicator.extensionUuid
          clipboard-indicator.extensionUuid
          dash-to-panel.extensionUuid
          gtile.extensionUuid
          kimpanel.extensionUuid
          media-controls.extensionUuid
          pip-on-top.extensionUuid
          vertical-workspaces.extensionUuid
          vitals.extensionUuid
          weather-oclock.extensionUuid
          user-themes.extensionUuid
        ];

        favorite-apps = [
          "google-chrome.desktop"
          "org.gnome.Nautilus.desktop"
          "Alacritty.desktop"
        ];
      };

      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        show-battery-percentage = true;
        clock-format = "24h";
        clock-show-date = true;
        clock-show-seconds = false;
        clock-show-weekday = true;
        enable-animations = true;
      };

      "org/gnome/desktop/wm/preferences" = {
        button-layout = "appmenu:minimize,maximize,close";
      };

      "org/gnome/settings-daemon/plugins/xsettings" = {
        overrides = lib.hm.gvariant.mkArray "{sv}" [
          (lib.hm.gvariant.mkDictionaryEntry [
            "Gtk/IMModule"
            (lib.hm.gvariant.mkVariant "fcitx")
          ])
        ];
      };

      "org/gnome/mutter" = {
        workspaces-only-on-primary = false;
        center-new-windows = true;
        dynamic-workspaces = false;
        experimental-features = [
          "scale-monitor-framebuffer"
          "xwayland-native-scaling"
        ];
      };

      "org/gnome/shell/extensions/vertical-workspaces" = {
        animation-speed-factor = 30;
        ws-max-spacing = 16;
        ws-thumbnail-scale = 16;
        secondary-ws-thumbnail-scale = 16;
        ws-switcher-mode = 1;
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
        animate-app-switch = true;
        animate-appicon-hover = true;
        animate-appicon-hover-animation-duration = [
          (lib.hm.gvariant.mkDictionaryEntry [
            "RIPPLE"
            70
          ])
          (lib.hm.gvariant.mkDictionaryEntry [
            "PLANK"
            60
          ])
          (lib.hm.gvariant.mkDictionaryEntry [
            "SIMPLE"
            80
          ])
        ];
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
        animate-window-launch = true;
        appicon-margin = 0;
        appicon-padding = 6;
        appicon-style = "NORMAL";
        dot-position = "BOTTOM";
        dot-style-focused = "DOTS";
        dot-style-unfocused = "DOTS";
        # extension-version = 72;
        focus-highlight = false;
        global-border-radius = 8;
        hotkeys-overlay-combo = "TEMPORARILY";
        intellihide = false;
        intellihide-animation-time = 80;
        leftbox-padding = 4;
        location-clock = "BUTTONSLEFT";
        multi-monitors = false;
        panel-anchors = ''{"AUS-S2LMQS085997":"MIDDLE","GSM-0x000083cb":"MIDDLE"}'';
        panel-element-positions = builtins.toJSON {
          "AUS-S2LMQS085997" = panelElements;
          "GSM-0x000083cb" = panelElements;
        };
        panel-element-positions-monitors-sync = true;
        panel-lengths = ''{"AUS-S2LMQS085997":100,"GSM-0x000083cb":100}'';
        panel-positions = ''{"AUS-S2LMQS085997":"TOP","GSM-0x000083cb":"TOP"}'';
        panel-side-margins = 4;
        panel-side-padding = 4;
        panel-sizes = ''{"AUS-S2LMQS085997":28,"GSM-0x000083cb":28}'';
        panel-top-bottom-padding = 0;
        panel-top-bottom-margins = 0;
        peek-mode = true;
        prefs-opened = false;
        show-appmenu = false;
        show-apps-icon-side-padding = 4;
        show-favorites = true;
        show-favorites-all-monitors = true;
        show-running-apps = true;
        show-tooltip = true;
        show-window-previews = true;
        show-window-previews-timeout = 150;
        status-icon-padding = 4;
        taskbar-position = "LEFTPANEL_FIXEDCENTER";
        trans-gradient-bottom-color = "#ffffff";
        trans-panel-opacity = 0.2;
        trans-use-border = false;
        trans-use-custom-bg = false;
        trans-use-custom-gradient = false;
        trans-use-custom-opacity = true;
        trans-use-dynamic-opacity = false;
        tray-padding = 4;
        window-preview-animation-time = 80;
        window-preview-title-position = "TOP";
      };

      "org/gnome/shell/extensions/mediacontrols" = {
        elements-order = [
          "ICON"
          "LABEL"
          "CONTROLS"
        ];
        extension-index = lib.hm.gvariant.mkUint32 0;
        extension-position = "Center";
        labels-order = [
          "TITLE"
          "-"
          "ARTIST"
        ];
        scroll-labels = true;
        show-control-icons = true;
        show-label = true;
        show-player-icon = true;
      };

      "org/gnome/shell/extensions/vitals" = {
        alphabetize = false;
        fixed-widths = true;
        hide-icons = false;
        hot-sensors = [
          "__temperature_max__"
          "_processor_usage_"
          "_memory_usage_"
        ];
        position-in-panel = 2;
        update-time = 5;
        use-higher-precision = false;
      };

      "org/gnome/shell/extensions/clipboard-indicator" = {
        display-mode = 0;
        history-size = 50;
        notify-on-copy = false;
        toggle-menu = [ "<Super>v" ];
      };

    };
  };

  stylix.targets.gtk.extraCss = ''
    headerbar { min-height: 28px; padding: 2px 4px; }
  '';
}
