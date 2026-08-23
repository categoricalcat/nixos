{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  colors = import ../theme.nix;
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
      element = "dateMenu";
      visible = true;
      position = "centerMonitor";
    }
    {
      element = "centerBox";
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

  hasPaperWM = builtins.any (
    p: (p.extensionUuid or "") == pkgs.gnomeExtensions.paperwm.extensionUuid
  ) osConfig.environment.systemPackages;
in

{
  dconf = {
    enable = true;
    settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        disable-extension-version-validation = true;
        enabled-extensions = map (p: p.extensionUuid) (
          builtins.filter (p: p ? extensionUuid) osConfig.environment.systemPackages
        );

        favorite-apps = [
          "google-chrome.desktop"
          "org.gnome.Nautilus.desktop"
          "kitty.desktop"
        ];
      };

      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        accent-color = "teal";
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

      "org/gnome/desktop/wm/keybindings" = {
        close = [ "<Super>q" ];
        switch-windows = [ "<Alt>Tab" ];
        switch-windows-backward = [ "<Shift><Alt>Tab" ];
        switch-applications = [ "<Super>Tab" ];
        switch-applications-backward = [ "<Shift><Super>Tab" ];
      };

      "org/gnome/mutter" = {
        # workspaces-only-on-primary = true; # Option 2: Native GNOME behavior (Primary monitor gets multiple workspaces, secondary static)
        workspaces-only-on-primary = false;
        center-new-windows = true;
        dynamic-workspaces = hasPaperWM;
        experimental-features = [
          "scale-monitor-framebuffer"
          "xwayland-native-scaling"
          "kms-modifiers"
          "variable-refresh-rate"
        ];
      };

      "org/gnome/shell/extensions/vertical-workspaces" = {
        animation-speed-factor = 50;
        ws-max-spacing = 16;
        ws-switcher-mode = 1;
      };

      "org/gnome/shell/extensions/paperwm" = {
        horizontal-margin = 0;
        vertical-margin = 0;
        vertical-margin-bottom = 0;
        window-gap = 0;
        animation-time = 0.0;
        selection-border-size = 1;
        selection-border-radius-top = 4;
        selection-border-radius-bottom = 4;
      };

      "org/gnome/shell/extensions/paperwm/keybindings" = {
        # switch-left = [
        #   "<Super>Left"
        #   "<Super>b"
        # ];
        # switch-right = [
        #   "<Super>Right"
        #   "<Super>f"
        # ];
        switch-right = [
          "<Super>Up"
          "<Super>p"
        ];
        switch-left = [
          "<Super>Down"
          "<Super>n"
        ];
        move-left = [
          "<Super><Ctrl>Left"
          "<Super><Shift>b"
        ];
        move-right = [
          "<Super><Ctrl>Right"
          "<Super><Shift>f"
        ];
        move-up = [
          "<Super><Ctrl>Up"
          "<Super><Shift>p"
        ];
        move-down = [
          "<Super><Ctrl>Down"
          "<Super><Shift>n"
        ];
        toggle-maximize-width = [ "<Super>m" ];
        paper-toggle-fullscreen = [ "<Super><Shift>m" ];
        new-window = [ "<Super>Return" ];
        take-window = [ ];
      };

      "org/gnome/shell/keybindings" = {
        show-screenshot-ui = [ "<Shift><Super>s" ];
      };

      # Input and touchpad
      "org/gnome/desktop/peripherals/touchpad" = {
        tap-to-click = true;
        natural-scroll = true;
        click-method = "fingers";
      };

      # Night Light
      "org/gnome/settings-daemon/plugins/color" = {
        night-light-enabled = true;
        night-light-schedule-automatic = true;
        night-light-temperature = lib.hm.gvariant.mkUint32 3700;
      };

      "org/gnome/desktop/session" = lib.mkIf (osConfig.networking.hostName == "yitaishi") {
        idle-delay = lib.hm.gvariant.mkUint32 0;
      };

      "org/gnome/settings-daemon/plugins/power" = lib.mkIf (osConfig.networking.hostName == "yitaishi") {
        idle-dim = false;
        sleep-inactive-ac-timeout = 0;
        sleep-inactive-ac-type = "nothing";
        sleep-inactive-battery-timeout = 0;
        sleep-inactive-battery-type = "nothing";
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
        group-apps-label-font-weight = "normal";
        window-preview-title-font-weight = "normal";
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
        panel-anchors = builtins.toJSON (
          lib.genAttrs (lib.imap0 (i: _: toString i) osConfig.desktop.monitors) (_m: "MIDDLE")
        );
        panel-element-positions = builtins.toJSON (
          lib.genAttrs (lib.imap0 (i: _: toString i) osConfig.desktop.monitors) (_m: panelElements)
        );
        panel-element-positions-monitors-sync = true;
        panel-lengths = builtins.toJSON (
          lib.genAttrs (lib.imap0 (i: _: toString i) osConfig.desktop.monitors) (_m: 100)
        );
        panel-positions = builtins.toJSON (
          lib.genAttrs (lib.imap0 (i: _: toString i) osConfig.desktop.monitors) (_m: "TOP")
        );
        panel-side-margins = 4;
        panel-side-padding = 4;
        panel-sizes = builtins.toJSON (
          lib.genAttrs (lib.imap0 (i: _: toString i) osConfig.desktop.monitors) (_m: 28)
        );
        panel-top-bottom-padding = 0;
        panel-top-bottom-margins = 0;
        peek-mode = true;
        prefs-opened = false;
        show-appmenu = true;
        show-apps-icon-side-padding = 4;
        show-favorites = true;
        show-favorites-all-monitors = true;
        show-running-apps = true;
        show-tooltip = true;
        show-window-previews = true;
        show-window-previews-timeout = 150;
        status-icon-padding = 4;
        taskbar-position = "LEFTPANEL_FIXEDCENTER";
        trans-gradient-bottom-color = "#${colors.base05}";
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

      "org/gnome/shell/extensions/vitals" = {
        alphabetize = false;
        fixed-widths = true;
        hide-icons = false;
        hot-sensors = [
          "__temperature_avg__"
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

      "org/gnome/system/location" = {
        enabled = true;
        max-accuracy-level = "exact";
        automatic-location = true;
      };

      "org/gnome/shell/weather" = {
        automatic-location = osConfig.networking.hostName != "yitaishi";
      };

      "org/gnome/shell/extensions/mpris-label" = {
        extension-place = "center";
        max-string-length = 14;
        left-padding = 0;
        right-padding = 0;
      };

      "org/gnome/settings-daemon/plugins/media-keys" = {
        mic-mute = [ "F12" ];
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
        ];
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        binding = "<Super>period";
        command = "smile";
        name = "Smile Emoji Picker";
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
        binding = "Print";
        command = "ksnip -r";
        name = "Ksnip Screenshot";
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
        binding = "<Super>t";
        command = "kitty";
        name = "Kitty Terminal";
      };

    };
  };

  stylix.targets.gtk.extraCss = ''
    headerbar { min-height: 28px; padding: 2px 4px; border-radius: 8px; }
  '';

  gtk.enable = true;
}
