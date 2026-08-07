{
  lib,
  pkgs,
  desktopShell ? "none",
  monitors ? [ ],
  inputs,
  ...
}:

let
  colors = import ../../modules/theme.nix;

  parseMode =
    mode:
    if mode == null then
      null
    else
      let
        m = builtins.match "([0-9]+)x([0-9]+)(@([0-9.]+))?" mode;
      in
      if m == null then
        null
      else
        {
          width = builtins.fromJSON (builtins.elemAt m 0);
          height = builtins.fromJSON (builtins.elemAt m 1);
          refresh =
            let
              r = builtins.elemAt m 3;
            in
            if r == null then null else (builtins.fromJSON r) * 1.0;
        };

  parseTransform = t: {
    rotation =
      {
        normal = 0;
        "90" = 90;
        "180" = 180;
        "270" = 270;
        flipped = 0;
        "flipped-90" = 90;
        "flipped-180" = 180;
        "flipped-270" = 270;
      }
      .${t};
    flipped = lib.hasPrefix "flipped" t;
  };

  typedOutputs = builtins.listToAttrs (
    map (m: {
      inherit (m) name;
      value = {
        mode = parseMode m.mode;
        inherit (m) scale;
        transform = parseTransform m.transform;
        position = lib.optionalAttrs (m.position != null) {
          x = m.position.x;
          y = m.position.y;
        };
      };
    }) monitors
  );

  numberedBinds = builtins.listToAttrs (
    lib.flatten (
      map (n: [
        {
          name = "Mod+${toString n}";
          value.action."focus-workspace" = [ n ];
        }
        {
          name = "Mod+Ctrl+${toString n}";
          value.action."move-column-to-workspace" = [ n ];
        }
      ]) (lib.range 1 9)
    )
  );

  baseBinds = {
    "Mod+Shift+Slash".action."show-hotkey-overlay" = [ ];
    "Mod+T".action."spawn" = [ "kitty" ];
    "Super+Alt+L".action."spawn" = [ "swaylock" ];
    "Super+Alt+S" = {
      allow-when-locked = true;
      action."spawn-sh" = [ "pkill orca || exec orca" ];
    };
    "Mod+O" = {
      repeat = false;
      action."toggle-overview" = [ ];
    };
    "Mod+Tab" = {
      repeat = false;
      action."toggle-overview" = [ ];
    };
    "Mod+Q" = {
      repeat = false;
      action."close-window" = [ ];
    };

    "Mod+Left".action."focus-column-left" = [ ];
    "Mod+Down".action."focus-window-down" = [ ];
    "Mod+Up".action."focus-window-up" = [ ];
    "Mod+Right".action."focus-column-right" = [ ];
    "Mod+H".action."focus-column-left" = [ ];
    "Mod+J".action."focus-window-down" = [ ];
    "Mod+K".action."focus-window-up" = [ ];
    "Mod+L".action."focus-column-right" = [ ];

    "Mod+Ctrl+Left".action."move-column-left" = [ ];
    "Mod+Ctrl+Down".action."move-window-down" = [ ];
    "Mod+Ctrl+Up".action."move-window-up" = [ ];
    "Mod+Ctrl+Right".action."move-column-right" = [ ];
    "Mod+Ctrl+H".action."move-column-left" = [ ];
    "Mod+Ctrl+J".action."move-window-down" = [ ];
    "Mod+Ctrl+K".action."move-window-up" = [ ];
    "Mod+Ctrl+L".action."move-column-right" = [ ];

    "Mod+Home".action."focus-column-first" = [ ];
    "Mod+End".action."focus-column-last" = [ ];
    "Mod+Ctrl+Home".action."move-column-to-first" = [ ];
    "Mod+Ctrl+End".action."move-column-to-last" = [ ];

    "Mod+Shift+Left".action."move-column-left" = [ ];
    "Mod+Shift+Down".action."move-window-down" = [ ];
    "Mod+Shift+Up".action."move-window-up" = [ ];
    "Mod+Shift+Right".action."move-column-right" = [ ];
    "Mod+Shift+H".action."move-column-left" = [ ];
    "Mod+Shift+J".action."move-window-down" = [ ];
    "Mod+Shift+K".action."move-window-up" = [ ];
    "Mod+Shift+L".action."move-column-right" = [ ];

    "Mod+Shift+Ctrl+Left".action."move-column-to-monitor-left" = [ ];
    "Mod+Shift+Ctrl+Down".action."move-column-to-monitor-down" = [ ];
    "Mod+Shift+Ctrl+Up".action."move-column-to-monitor-up" = [ ];
    "Mod+Shift+Ctrl+Right".action."move-column-to-monitor-right" = [ ];
    "Mod+Shift+Ctrl+H".action."move-column-to-monitor-left" = [ ];
    "Mod+Shift+Ctrl+J".action."move-column-to-monitor-down" = [ ];
    "Mod+Shift+Ctrl+K".action."move-column-to-monitor-up" = [ ];
    "Mod+Shift+Ctrl+L".action."move-column-to-monitor-right" = [ ];

    "Mod+Page_Down".action."focus-workspace-down" = [ ];
    "Mod+Page_Up".action."focus-workspace-up" = [ ];
    "Mod+U".action."focus-workspace-down" = [ ];
    "Mod+I".action."focus-workspace-up" = [ ];
    "Mod+Ctrl+Page_Down".action."move-column-to-workspace-down" = [ ];
    "Mod+Ctrl+Page_Up".action."move-column-to-workspace-up" = [ ];
    "Mod+Ctrl+U".action."move-column-to-workspace-down" = [ ];
    "Mod+Ctrl+I".action."move-column-to-workspace-up" = [ ];

    "Mod+Shift+Page_Down".action."move-workspace-down" = [ ];
    "Mod+Shift+Page_Up".action."move-workspace-up" = [ ];
    "Mod+Shift+U".action."move-workspace-down" = [ ];
    "Mod+Shift+I".action."move-workspace-up" = [ ];

    "Mod+WheelScrollDown" = {
      cooldown-ms = 150;
      action."focus-workspace-down" = [ ];
    };
    "Mod+WheelScrollUp" = {
      cooldown-ms = 150;
      action."focus-workspace-up" = [ ];
    };
    "Mod+Ctrl+WheelScrollDown" = {
      cooldown-ms = 150;
      action."move-column-to-workspace-down" = [ ];
    };
    "Mod+Ctrl+WheelScrollUp" = {
      cooldown-ms = 150;
      action."move-column-to-workspace-up" = [ ];
    };
    "Mod+WheelScrollRight".action."focus-column-right" = [ ];
    "Mod+WheelScrollLeft".action."focus-column-left" = [ ];
    "Mod+Ctrl+WheelScrollRight".action."move-column-right" = [ ];
    "Mod+Ctrl+WheelScrollLeft".action."move-column-left" = [ ];
    "Mod+Shift+WheelScrollDown".action."focus-column-right" = [ ];
    "Mod+Shift+WheelScrollUp".action."focus-column-left" = [ ];
    "Mod+Ctrl+Shift+WheelScrollDown".action."move-column-right" = [ ];
    "Mod+Ctrl+Shift+WheelScrollUp".action."move-column-left" = [ ];

    "Mod+BracketLeft".action."consume-or-expel-window-left" = [ ];
    "Mod+BracketRight".action."consume-or-expel-window-right" = [ ];
    "Mod+Comma".action."consume-window-into-column" = [ ];
    "Mod+Period".action."spawn" = [ "smile" ];

    "Mod+R".action."switch-preset-column-width" = [ ];
    "Mod+Shift+R".action."switch-preset-window-height" = [ ];
    "Mod+Ctrl+R".action."reset-window-height" = [ ];
    "Mod+F".action."maximize-column" = [ ];
    "Mod+Shift+F".action."fullscreen-window" = [ ];
    "Mod+Ctrl+F".action."expand-column-to-available-width" = [ ];
    "Mod+C".action."center-column" = [ ];
    "Mod+Ctrl+C".action."center-visible-columns" = [ ];
    "Mod+Minus".action."set-column-width" = [ "-10%" ];
    "Mod+Equal".action."set-column-width" = [ "+10%" ];
    "Mod+Shift+Minus".action."set-window-height" = [ "-10%" ];
    "Mod+Shift+Equal".action."set-window-height" = [ "+10%" ];
    "Mod+Shift+V".action."toggle-window-floating" = [ ];
    "Mod+W".action."toggle-column-tabbed-display" = [ ];

    "XF86AudioRaiseVolume" = {
      allow-when-locked = true;
      action."spawn-sh" = [ "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+" ];
    };
    "XF86AudioLowerVolume" = {
      allow-when-locked = true;
      action."spawn-sh" = [ "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-" ];
    };
    "XF86AudioMute" = {
      allow-when-locked = true;
      action."spawn-sh" = [ "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" ];
    };
    "XF86AudioMicMute" = {
      allow-when-locked = true;
      action."spawn-sh" = [ "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" ];
    };
    "XF86MonBrightnessUp" = {
      allow-when-locked = true;
      action."spawn" = [
        "brightnessctl"
        "--class=backlight"
        "set"
        "+10%"
      ];
    };
    "XF86MonBrightnessDown" = {
      allow-when-locked = true;
      action."spawn" = [
        "brightnessctl"
        "--class=backlight"
        "set"
        "10%-"
      ];
    };

    "Print".action."screenshot" = [ ];
    "Ctrl+Print".action."screenshot-screen" = [ ];
    "Alt+Print".action."screenshot-window" = [ ];
    "F12".action."spawn" = [
      "wpctl"
      "set-mute"
      "@DEFAULT_AUDIO_SOURCE@"
      "toggle"
    ];

    "Mod+Escape" = {
      allow-inhibiting = false;
      action."toggle-keyboard-shortcuts-inhibit" = [ ];
    };
    "Mod+Shift+E".action."quit" = [ ];
    "Ctrl+Alt+Delete".action."quit" = [ ];
    "Mod+Shift+P".action."power-off-monitors" = [ ];
  };

  shellLauncherBind =
    if desktopShell == "noctalia" then
      {
        "Mod+Space" = {
          hotkey-overlay.title = "Run an Application: noctalia";
          action."spawn" = [
            "noctalia"
            "msg"
            "panel-toggle"
            "launcher"
          ];
        };
      }
    else
      { };

  dmsEmbedded = "${inputs.dms.outPath}/core/internal/config/embedded";
in
{
  # homeModules.config is auto-imported via home-manager.sharedModules by the
  # niri NixOS module for NixOS hosts, and via flake.nix for homeConfigurations.yijia.
  imports =
    lib.optional (desktopShell == "dms") inputs.dms.homeModules.niri
    ++ lib.optional (desktopShell == "dms") ./niri-dms.nix;

  config = {
    xdg.enable = true;

    programs.niri.package = pkgs.niri-unstable;
    programs.niri.settings = {
      prefer-no-csd = true;

      spawn-at-startup = [
        {
          argv = [
            "bash"
            "-c"
            "wl-paste --watch cliphist store &"
          ];
        }
        { argv = [ "niri-float-sticky" ]; }
      ];

      environment = {
        XDG_CURRENT_DESKTOP = "niri";
        QT_QPA_PLATFORM = "wayland";
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
        QT_QPA_PLATFORMTHEME = "qt6ct";
        QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
        TERMINAL = "kitty";
      };

      hotkey-overlay.skip-at-startup = true;

      screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

      overview.backdrop-color = "#${colors.base00}";

      input = {
        touchpad = {
          tap = true;
          natural-scroll = true;
        };
        warp-mouse-to-focus.enable = true;
        focus-follows-mouse = {
          enable = true;
          max-scroll-amount = "0%";
        };
      };

      outputs = typedOutputs;

      layout = {
        gaps = 4;
        background-color = "transparent";
        center-focused-column = "never";
        preset-column-widths = [
          { proportion = 0.33333; }
          { proportion = 0.5; }
          { proportion = 0.66667; }
        ];
        default-column-width = {
          proportion = 0.5;
        };
        focus-ring = {
          enable = true;
          width = 0.5;
          active = {
            color = "#${colors.base05}";
          };
          inactive = {
            color = "#${colors.base03}";
          };
        };
        border.enable = false;
        shadow = {
          enable = true;
          softness = 30;
          spread = 5;
          offset = {
            x = 0;
            y = 5;
          };
          color = "#${colors.base00}";
        };
      };

      window-rules = [
        {
          matches = [ { title = "(?i)picture-in-picture"; } ];
          open-floating = true;
        }
        {
          geometry-corner-radius = {
            top-left = 6.0;
            top-right = 6.0;
            bottom-left = 6.0;
            bottom-right = 6.0;
          };
          clip-to-geometry = true;
          draw-border-with-background = false;
        }
      ];

      binds = baseBinds // numberedBinds // shellLauncherBind;
    };

    xdg.configFile = lib.mkIf (desktopShell == "dms") {
      "niri/dms/binds.kdl".text = builtins.replaceStrings [ "{{TERMINAL_COMMAND}}" ] [ "kitty" ] (
        builtins.readFile "${dmsEmbedded}/niri-binds.kdl"
      );
    };
  };
}
