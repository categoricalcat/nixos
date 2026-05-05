{
  inputs,
  pkgs,
  ...
}:

let
  themeAssets = import ../theme-assets.nix { inherit inputs pkgs; };
  font = {
    family = themeAssets.fonts.sansSerif.name;
    pointSize = themeAssets.fonts.sizes.applications;
  };
  smallFont = font // {
    pointSize = 9;
  };
in
{
  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  # KDE shortcut cheatsheet
  #
  # Super: open app launcher/dashboard.
  # Super+W: show Overview.
  # Super+G: show Desktop Grid.
  # Super+Ctrl+Up/Down: switch virtual desktops vertically.
  # Super+Shift+Ctrl+Up/Down: move the focused window vertically.
  # Super+Alt+Up/Down/Left/Right: focus windows directionally.

  home.packages = [
    themeAssets.cursor.package
    themeAssets.icons.package
  ]
  ++ themeAssets.fonts.packages;

  programs.plasma = {
    enable = true;

    # Leave room for GUI experiments while the KDE workflow is still settling.
    overrideConfig = false;

    workspace = {
      lookAndFeel = "org.kde.breezedark.desktop";
      theme = "breeze-dark";
      widgetStyle = "Breeze";
      iconTheme = themeAssets.icons.dark;
      wallpaper = ./wallpaper.jpg;
      wallpaperFillMode = "crop";
      clickItemTo = "open";
      enableMiddleClickPaste = false;

      cursor = {
        theme = themeAssets.cursor.name;
        inherit (themeAssets.cursor) size;
        cursorFeedback = "None";
        taskManagerFeedback = false;
      };

      splashScreen = {
        theme = "None";
        engine = "none";
      };
    };

    fonts = {
      general = font;
      fixedWidth = font;
      menu = font;
      toolbar = font;
      windowTitle = font;
      small = smallFont;
    };

    panels = [
      {
        location = "top";
        height = 30;
        hiding = "none";
        floating = false;
        opacity = "adaptive";
        widgets = [
          {
            kickoff = {
              icon = "view-app-grid-symbolic";
              sortAlphabetically = true;
            };
          }
          {
            iconTasks = {
              launchers = [
                "applications:google-chrome.desktop"
                "applications:org.kde.dolphin.desktop"
                "applications:Alacritty.desktop"
              ];
            };
          }
          "org.kde.plasma.panelspacer"
          "org.kde.plasma.pager"
          "org.kde.plasma.digitalclock"
          "org.kde.plasma.systemtray"
        ];
      }
    ];

    kwin = {
      borderlessMaximizedWindows = true;
      cornerBarrier = false;
      edgeBarrier = 0;

      virtualDesktops = {
        number = 6;
        rows = 6;
        names = [
          "1"
          "2"
          "3"
          "4"
          "5"
          "6"
        ];
      };

      effects = {
        blur.enable = true;
        desktopSwitching = {
          animation = "slide";
          navigationWrapping = false;
        };
        windowOpenClose.animation = "scale";
      };
    };

    shortcuts = {
      plasmashell = {
        "activate application launcher" = "Alt+F1";
      };

      kwin = {
        Overview = "Meta+W";
        "Grid View" = "Meta+G";
        "Switch One Desktop Up" = "Meta+Ctrl+Up";
        "Switch One Desktop Down" = "Meta+Ctrl+Down";
        "Window One Desktop Up" = "Meta+Ctrl+Shift+Up";
        "Window One Desktop Down" = "Meta+Ctrl+Shift+Down";
        "Switch Window Up" = "Meta+Alt+Up";
        "Switch Window Down" = "Meta+Alt+Down";
        "Switch Window Left" = "Meta+Alt+Left";
        "Switch Window Right" = "Meta+Alt+Right";
      };
    };

    configFile = {
      kdeglobals = {
        General = {
          TerminalApplication = "Alacritty";
          TerminalService = "Alacritty.desktop";
        };
        KDE = {
          SingleClick = true;
        };
      };

      kwinrc = {
        ModifierOnlyShortcuts.Meta = "org.kde.plasmashell,/PlasmaShell,org.kde.PlasmaShell,activateLauncherMenu";
      };
    };
  };
}
