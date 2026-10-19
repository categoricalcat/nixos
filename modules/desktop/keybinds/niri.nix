{
  lib,
  shellCommands,
  ...
}:

let
  toNiriKey =
    keyStr:
    let
      parts = lib.splitString "," keyStr;
      modsPart = lib.elemAt parts 0;
      keyPart = lib.elemAt parts 1;
      modMap = {
        "SUPER" = "Mod";
        "CTRL" = "Ctrl";
        "ALT" = "Alt";
        "SHIFT" = "Shift";
      };
      specialKeys = {
        "space" = "Space";
        "period" = "Period";
        "comma" = "Comma";
        "slash" = "Slash";
        "equal" = "Equal";
        "minus" = "Minus";
        "bracketleft" = "BracketLeft";
        "bracketright" = "BracketRight";
        "return" = "Return";
        "delete" = "Delete";
        "backspace" = "BackSpace";
        "escape" = "Escape";
        "tab" = "Tab";
      };
      mods = lib.filter (m: m != "" && m != "none") (lib.splitString "+" modsPart);
      niriMods = map (m: modMap.${m} or m) mods;
      keyUpper =
        specialKeys.${lib.toLower keyPart}
        or (if lib.stringLength keyPart == 1 then lib.toUpper keyPart else keyPart);
      allParts = niriMods ++ [ keyUpper ];
    in
    lib.concatStringsSep "+" allParts;

  getNiriBinds =
    {
      desktopShell ? "dms",
      hdr ? false,
      terminalCommand ? "kitty",
      emojiCommand ? "smile",
    }:
    let
      cmds = shellCommands.getShellCommands {
        inherit
          desktopShell
          hdr
          terminalCommand
          emojiCommand
          ;
      };

      spawnTitleBind = title: cmd: {
        hotkey-overlay.title = title;
        action.spawn = cmd;
      };

      # Numbered workspaces 1-9
      workspaceBinds = builtins.listToAttrs (
        lib.flatten (
          map (n: [
            {
              name = "Mod+${toString n}";
              value.action."focus-workspace" = [ n ];
            }
            {
              name = "Mod+Shift+${toString n}";
              value.action."move-column-to-workspace" = [ n ];
            }
            {
              name = "Mod+Ctrl+${toString n}";
              value.action."move-column-to-workspace" = [ n ];
            }
          ]) (lib.range 1 9)
        )
      );

      # Mouse wheel / axis bindings with 150ms cooldown
      wheelBinds = {
        "Mod+WheelScrollDown" = {
          cooldown-ms = 150;
          action."focus-column-right" = [ ];
        };
        "Mod+WheelScrollUp" = {
          cooldown-ms = 150;
          action."focus-column-left" = [ ];
        };
        "Mod+Ctrl+WheelScrollDown" = {
          cooldown-ms = 150;
          action."move-column-right" = [ ];
        };
        "Mod+Ctrl+WheelScrollUp" = {
          cooldown-ms = 150;
          action."move-column-left" = [ ];
        };
        "Mod+WheelScrollRight" = {
          cooldown-ms = 150;
          action."focus-column-right" = [ ];
        };
        "Mod+WheelScrollLeft" = {
          cooldown-ms = 150;
          action."focus-column-left" = [ ];
        };
        "Mod+Ctrl+WheelScrollRight" = {
          cooldown-ms = 150;
          action."move-column-right" = [ ];
        };
        "Mod+Ctrl+WheelScrollLeft" = {
          cooldown-ms = 150;
          action."move-column-left" = [ ];
        };
        "Mod+Shift+WheelScrollDown" = {
          cooldown-ms = 150;
          action."focus-workspace-down" = [ ];
        };
        "Mod+Shift+WheelScrollUp" = {
          cooldown-ms = 150;
          action."focus-workspace-up" = [ ];
        };
        "Mod+Ctrl+Shift+WheelScrollDown" = {
          cooldown-ms = 150;
          action."move-column-to-workspace-down" = [ ];
        };
        "Mod+Ctrl+Shift+WheelScrollUp" = {
          cooldown-ms = 150;
          action."move-column-to-workspace-up" = [ ];
        };
      };

      # Window & Column Navigation
      navBinds = {
        # Focus column / window
        "Mod+Left".action."focus-column-left" = [ ];
        "Mod+Right".action."focus-column-right" = [ ];
        "Mod+Up".action."focus-window-up" = [ ];
        "Mod+Down".action."focus-window-down" = [ ];
        "Mod+H".action."focus-column-left" = [ ];
        "Mod+L".action."focus-column-right" = [ ];
        "Mod+K".action."focus-window-up" = [ ];
        "Mod+J".action."focus-window-down" = [ ];

        # Move column / window
        "Mod+Shift+Left".action."move-column-left" = [ ];
        "Mod+Shift+Right".action."move-column-right" = [ ];
        "Mod+Shift+Up".action."move-window-up" = [ ];
        "Mod+Shift+Down".action."move-window-down" = [ ];
        "Mod+Shift+H".action."move-column-left" = [ ];
        "Mod+Shift+L".action."move-column-right" = [ ];
        "Mod+Shift+K".action."move-window-up" = [ ];
        "Mod+Shift+J".action."move-window-down" = [ ];

        # Column first / last
        "Mod+Home".action."focus-column-first" = [ ];
        "Mod+End".action."focus-column-last" = [ ];
        "Mod+Ctrl+Home".action."move-column-to-first" = [ ];
        "Mod+Ctrl+End".action."move-column-to-last" = [ ];

        # Monitor Navigation
        "Mod+Ctrl+Left".action."focus-monitor-left" = [ ];
        "Mod+Ctrl+Right".action."focus-monitor-right" = [ ];
        "Mod+Ctrl+H".action."focus-monitor-left" = [ ];
        "Mod+Ctrl+L".action."focus-monitor-right" = [ ];
        "Mod+Ctrl+K".action."focus-monitor-up" = [ ];
        "Mod+Ctrl+J".action."focus-monitor-down" = [ ];

        # Move column to monitor
        "Mod+Shift+Ctrl+Left".action."move-column-to-monitor-left" = [ ];
        "Mod+Shift+Ctrl+Right".action."move-column-to-monitor-right" = [ ];
        "Mod+Shift+Ctrl+Up".action."move-column-to-monitor-up" = [ ];
        "Mod+Shift+Ctrl+Down".action."move-column-to-monitor-down" = [ ];
        "Mod+Shift+Ctrl+H".action."move-column-to-monitor-left" = [ ];
        "Mod+Shift+Ctrl+L".action."move-column-to-monitor-right" = [ ];
        "Mod+Shift+Ctrl+K".action."move-column-to-monitor-up" = [ ];
        "Mod+Shift+Ctrl+J".action."move-column-to-monitor-down" = [ ];

        # Workspace Navigation
        "Mod+Page_Down".action."focus-workspace-down" = [ ];
        "Mod+Page_Up".action."focus-workspace-up" = [ ];
        "Mod+U".action."focus-workspace-down" = [ ];
        "Mod+I".action."focus-workspace-up" = [ ];

        # Move column to workspace
        "Mod+Ctrl+Page_Down".action."move-column-to-workspace-down" = [ ];
        "Mod+Ctrl+Page_Up".action."move-column-to-workspace-up" = [ ];
        "Mod+Ctrl+Down".action."move-column-to-workspace-down" = [ ];
        "Mod+Ctrl+Up".action."move-column-to-workspace-up" = [ ];
        "Mod+Ctrl+U".action."move-column-to-workspace-down" = [ ];
        "Mod+Ctrl+I".action."move-column-to-workspace-up" = [ ];

        # Move workspace
        "Mod+Shift+Page_Down".action."move-workspace-down" = [ ];
        "Mod+Shift+Page_Up".action."move-workspace-up" = [ ];
        "Mod+Shift+U".action."move-workspace-down" = [ ];
        "Mod+Shift+I".action."move-workspace-up" = [ ];
      };

      # Layout, sizing, and column management
      layoutBinds = {
        "Mod+R".action."switch-preset-column-width" = [ ];
        "Mod+Shift+R".action."switch-preset-window-height" = [ ];
        "Mod+Ctrl+R".action."reset-window-height" = [ ];
        "Mod+Alt+R" =
          if cmds.appCommands.workspaceRename != null then
            spawnTitleBind "Rename Workspace" cmds.appCommands.workspaceRename
          else
            { action."switch-preset-column-width-back" = [ ]; };
        "Mod+C".action."center-column" = [ ];
        "Mod+Ctrl+C".action."center-visible-columns" = [ ];
        "Mod+Ctrl+F".action."expand-column-to-available-width" = [ ];
        "Mod+Minus".action."set-column-width" = [ "-10%" ];
        "Mod+Equal".action."set-column-width" = [ "+10%" ];
        "Mod+Shift+Minus".action."set-window-height" = [ "-10%" ];
        "Mod+Shift+Equal".action."set-window-height" = [ "+10%" ];
        "Mod+BracketLeft".action."consume-or-expel-window-left" = [ ];
        "Mod+BracketRight".action."consume-or-expel-window-right" = [ ];
        "Mod+W".action."toggle-column-tabbed-display" = [ ];
      };

      # Window state controls
      windowStateBinds = {
        "Mod+Q" = {
          repeat = false;
          action."close-window" = [ ];
        };
        "Mod+F".action."fullscreen-window" = [ ];
        "Mod+Shift+F".action."maximize-column" = [ ];
        "Mod+Shift+Space" = {
          hotkey-overlay.title = "Toggle Floating";
          action."toggle-window-floating" = [ ];
        };
        "Mod+Shift+T" = {
          hotkey-overlay.title = "Toggle Floating";
          action."toggle-window-floating" = [ ];
        };
        "Mod+Shift+V".action."switch-focus-between-floating-and-tiling" = [ ];
        "Mod+O" = {
          repeat = false;
          action."toggle-overview" = [ ];
        };
        "Alt+Tab" = {
          repeat = false;
          action."toggle-overview" = [ ];
        };
        "Alt+Shift+Tab" = {
          repeat = false;
          action."toggle-overview" = [ ];
        };
        "Mod+Shift+E".action."quit" = [ ];
        # yixiaoqing option for all: Ctrl+Alt+Delete executes quit
        "Ctrl+Alt+Delete".action."quit" = [ ];
      };

      # Audio and brightness
      mediaBinds = {
        "XF86AudioRaiseVolume" = {
          allow-when-locked = true;
          action.spawn = cmds.audio.volumeUp;
        };
        "XF86AudioLowerVolume" = {
          allow-when-locked = true;
          action.spawn = cmds.audio.volumeDown;
        };
        "XF86AudioMute" = {
          allow-when-locked = true;
          action.spawn = cmds.audio.volumeMute;
        };
        "XF86AudioMicMute" = {
          allow-when-locked = true;
          action.spawn = cmds.audio.micMute;
        };
        "F12" = {
          allow-when-locked = true;
          action.spawn = cmds.audio.micMute;
        };
        "XF86AudioPlay" = {
          allow-when-locked = true;
          action.spawn = cmds.audio.mediaPlay;
        };
        "XF86AudioPause" = {
          allow-when-locked = true;
          action.spawn = cmds.audio.mediaPlay;
        };
        "XF86AudioPrev" = {
          allow-when-locked = true;
          action.spawn = cmds.audio.mediaPrev;
        };
        "XF86AudioNext" = {
          allow-when-locked = true;
          action.spawn = cmds.audio.mediaNext;
        };
        "XF86MonBrightnessUp" = {
          allow-when-locked = true;
          action.spawn = cmds.brightness.brightnessUp;
        };
        "XF86MonBrightnessDown" = {
          allow-when-locked = true;
          action.spawn = cmds.brightness.brightnessDown;
        };
        "XF86TouchpadToggle" = {
          allow-when-locked = true;
          repeat = false;
          action.spawn = [
            "niri"
            "msg"
            "action"
            "toggle-touchpad"
          ];
        };
      };

      # Screenshots
      screenshotBinds =
        if desktopShell == "dms" || hdr then
          {
            "Print" = {
              hotkey-overlay.title = "Screenshot: Region";
              action.spawn = cmds.screenshots.interactive;
            };
            "Mod+Shift+S" = {
              hotkey-overlay.title = "Screenshot: Region";
              action.spawn = cmds.screenshots.interactive;
            };
            "XF86Launch1" = {
              hotkey-overlay.title = "Screenshot: Region";
              action.spawn = cmds.screenshots.interactive;
            };
            "Ctrl+Print" = {
              hotkey-overlay.title = "Screenshot: Full Screen";
              action.spawn = cmds.screenshots.full;
            };
            "Ctrl+XF86Launch1" = {
              hotkey-overlay.title = "Screenshot: Full Screen";
              action.spawn = cmds.screenshots.full;
            };
            "Alt+Print" = {
              hotkey-overlay.title = "Screenshot: Window";
              action.spawn = cmds.screenshots.window;
            };
            "Alt+XF86Launch1" = {
              hotkey-overlay.title = "Screenshot: Window";
              action.spawn = cmds.screenshots.window;
            };
          }
        else
          {
            "Print".action."screenshot" = [ ];
            "Mod+Shift+S".action."screenshot" = [ ];
            "XF86Launch1".action."screenshot" = [ ];
            "Ctrl+Print".action."screenshot-screen" = [ ];
            "Ctrl+XF86Launch1".action."screenshot-screen" = [ ];
            "Alt+Print".action."screenshot-window" = [ ];
            "Alt+XF86Launch1".action."screenshot-window" = [ ];
          };

      # System & App Launcher Binds
      appBinds = {
        "Mod+T" = spawnTitleBind "Open Terminal" [ terminalCommand ];
        "Mod+Return" = spawnTitleBind "Open Terminal" [ terminalCommand ];
        "Mod+Period" = spawnTitleBind "Emoji Picker" [ emojiCommand ];
        "Super+Alt+L" = spawnTitleBind "Lock Screen" cmds.appCommands.lockScreen;
        "Super+Alt+S" = {
          allow-when-locked = true;
          action."spawn-sh" = [ "pkill orca || exec orca" ];
        };
        "Mod+Escape" = {
          allow-inhibiting = false;
          action."toggle-keyboard-shortcuts-inhibit" = [ ];
        };
        "Mod+Shift+P".action."power-off-monitors" = [ ];
      }
      // lib.optionalAttrs (cmds.appCommands.launcher != null) {
        "Mod+Space" = spawnTitleBind "Application Launcher" cmds.appCommands.launcher;
      }
      // lib.optionalAttrs (cmds.appCommands.launcherBar != null) {
        "Alt+Space" = spawnTitleBind "Spotlight Bar" cmds.appCommands.launcherBar;
      }
      // lib.optionalAttrs (cmds.appCommands.clipboard != null) {
        "Mod+V" = spawnTitleBind "Clipboard Manager" cmds.appCommands.clipboard;
      }
      // lib.optionalAttrs (cmds.appCommands.settings != null) {
        "Mod+Comma" = spawnTitleBind "Settings" cmds.appCommands.settings;
      }
      // lib.optionalAttrs (cmds.appCommands.settings == null) {
        "Mod+Comma".action."consume-window-into-column" = [ ];
      }
      // lib.optionalAttrs (cmds.appCommands.notifications != null) {
        "Mod+Ctrl+N" = spawnTitleBind "Notification Center" cmds.appCommands.notifications;
        "Mod+N" = spawnTitleBind "Notification Center" cmds.appCommands.notifications;
      }
      // lib.optionalAttrs (cmds.appCommands.notepad != null) {
        "Mod+N" = spawnTitleBind "Notepad" cmds.appCommands.notepad;
      }
      // lib.optionalAttrs (cmds.appCommands.notepadExpand != null) {
        "Mod+Shift+N" = spawnTitleBind "Notepad: Expand" cmds.appCommands.notepadExpand;
      }
      // lib.optionalAttrs (cmds.appCommands.wallpapers != null) {
        "Mod+Y" = spawnTitleBind "Browse Wallpapers" cmds.appCommands.wallpapers;
      }
      // lib.optionalAttrs (cmds.appCommands.powerMenu != null) {
        "Mod+X" = spawnTitleBind "Power Menu: Toggle" cmds.appCommands.powerMenu;
      }
      // lib.optionalAttrs (cmds.appCommands.displayProfile != null) {
        "Mod+P" = spawnTitleBind "Cycle Display Profile" cmds.appCommands.displayProfile;
      }
      // lib.optionalAttrs (cmds.appCommands.keybindsHelp != null) {
        "Mod+Shift+Slash" = spawnTitleBind "Keyboard Shortcuts" cmds.appCommands.keybindsHelp;
      }
      // lib.optionalAttrs (cmds.appCommands.keybindsHelp == null) {
        "Mod+Shift+Slash".action."show-hotkey-overlay" = [ ];
      }
      // lib.optionalAttrs (cmds.appCommands.windowRules != null) {
        "Mod+Shift+W" = spawnTitleBind "Create window rule" cmds.appCommands.windowRules;
      }
      // lib.optionalAttrs (cmds.appCommands.mediaDashboard != null) {
        "Mod+M" = spawnTitleBind "Media" cmds.appCommands.mediaDashboard;
      }
      //
        lib.optionalAttrs (cmds.appCommands.mediaDashboard == null && cmds.appCommands.taskManager != null)
          {
            "Mod+M" = spawnTitleBind "Task Manager" cmds.appCommands.taskManager;
          }
      // lib.optionalAttrs (cmds.appCommands.taskManager != null) {
        "Ctrl+Alt+M" = spawnTitleBind "Task Manager" cmds.appCommands.taskManager;
      }
      // lib.optionalAttrs (cmds.appCommands.controlCenter != null) {
        "Mod+A" = spawnTitleBind "Control Center" cmds.appCommands.controlCenter;
      }
      // lib.optionalAttrs (cmds.appCommands.dash != null) {
        "Mod+D" = spawnTitleBind "Dash" cmds.appCommands.dash;
      }
      // lib.optionalAttrs (cmds.appCommands.colorPicker != null) {
        "Mod+Shift+C" = spawnTitleBind "Color Picker" cmds.appCommands.colorPicker;
      }
      // lib.optionalAttrs (cmds.appCommands.nightMode != null) {
        "Mod+Alt+N" = spawnTitleBind "Night Mode" cmds.appCommands.nightMode;
      }
      // lib.optionalAttrs (cmds.appCommands.idleInhibit != null) {
        "Mod+Alt+I" = spawnTitleBind "Idle Inhibit" cmds.appCommands.idleInhibit;
      };
    in
    workspaceBinds
    // wheelBinds
    // navBinds
    // layoutBinds
    // windowStateBinds
    // mediaBinds
    // screenshotBinds
    // appBinds;

  # Format args list into KDL quotes: [ "dms" "ipc" "call" ] -> '"dms" "ipc" "call"'
  formatKdlArgs =
    args:
    lib.concatStringsSep " " (map (a: ''"${builtins.replaceStrings [ "\"" ] [ "\\\"" ] a}"'') args);

  # Generate clean KDL text for dms/binds.kdl
  generateDmsBindsKdl =
    {
      desktopShell ? "dms",
      hdr ? false,
      terminalCommand ? "kitty",
      emojiCommand ? "smile",
    }:
    let
      binds = getNiriBinds {
        inherit
          desktopShell
          hdr
          terminalCommand
          emojiCommand
          ;
      };

      formatBindKdl =
        key: val:
        let
          flags =
            (lib.optionalString (val ? allow-when-locked && val.allow-when-locked) " allow-when-locked=true")
            + (lib.optionalString (val ? allow-inhibiting && !val.allow-inhibiting) " allow-inhibiting=false")
            + (lib.optionalString (val ? repeat && !val.repeat) " repeat=false")
            + (lib.optionalString (val ? cooldown-ms) " cooldown-ms=${toString val.cooldown-ms}")
            + (lib.optionalString (
              val ? hotkey-overlay.title
            ) " hotkey-overlay-title=\"${val.hotkey-overlay.title}\"");

          actionName = builtins.head (builtins.attrNames val.action);
          actionArgs = val.action.${actionName};

          actionBody =
            if actionName == "spawn" then
              "spawn ${formatKdlArgs actionArgs};"
            else if actionName == "spawn-sh" then
              "spawn-sh \"${builtins.replaceStrings [ "\"" ] [ "\\\"" ] (builtins.head actionArgs)}\";"
            else if actionArgs == [ ] then
              "${actionName};"
            else
              "${actionName} ${
                lib.concatStringsSep " " (
                  map (a: if builtins.isString a then ''"${a}"'' else toString a) actionArgs
                )
              };";
        in
        "    ${key}${flags} { ${actionBody} }";

      bindLines = lib.concatStringsSep "\n" (lib.mapAttrsToList formatBindKdl binds);
    in
    ''
      binds {
      ${bindLines}
      }

      recent-windows {
          binds {
              Mod+Tab         { next-window; }
              Mod+Shift+Tab   { previous-window; }
              Mod+grave       { next-window     filter="app-id"; }
              Mod+Shift+grave { previous-window filter="app-id"; }
          }
      }
    '';
in
{
  inherit
    toNiriKey
    getNiriBinds
    generateDmsBindsKdl
    ;
}
