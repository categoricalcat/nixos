_:

{
  # Returns resolved shell commands for launchers, screenshots, audio, and session controls.
  getShellCommands =
    {
      desktopShell ? "dms",
      hdr ? false,
      terminalCommand ? "kitty",
      emojiCommand ? "smile",
    }:
    let
      # Shell-specific application commands
      appCommands =
        if desktopShell == "dms" then
          {
            launcher = [
              "dms"
              "ipc"
              "call"
              "spotlight"
              "toggle"
            ];
            launcherBar = [
              "dms"
              "ipc"
              "call"
              "spotlight-bar"
              "toggle"
            ];
            clipboard = [
              "dms"
              "ipc"
              "call"
              "clipboard"
              "toggle"
            ];
            settings = [
              "dms"
              "ipc"
              "call"
              "settings"
              "focusOrToggle"
            ];
            notifications = [
              "dms"
              "ipc"
              "call"
              "notifications"
              "toggle"
            ];
            notepad = [
              "dms"
              "ipc"
              "call"
              "notepad"
              "toggle"
            ];
            notepadExpand = [
              "dms"
              "ipc"
              "call"
              "notepad"
              "toggleExpand"
            ];
            wallpapers = [
              "dms"
              "ipc"
              "call"
              "dash"
              "toggle"
              "wallpaper"
            ];
            powerMenu = [
              "dms"
              "ipc"
              "call"
              "powermenu"
              "toggle"
            ];
            taskManager = [
              "dms"
              "ipc"
              "call"
              "processlist"
              "focusOrToggle"
            ];
            displayProfile = [
              "dms"
              "ipc"
              "outputs"
              "cycleProfile"
            ];
            lockScreen = [
              "dms"
              "ipc"
              "call"
              "lock"
              "lock"
            ];
            keybindsHelp = [
              "dms"
              "ipc"
              "call"
              "keybinds"
              "toggle"
              "niri"
            ];
            keybindsHelpMango = [
              "dms"
              "ipc"
              "call"
              "keybinds"
              "toggle"
              "mangowc"
            ];
            windowRules = [
              "dms"
              "ipc"
              "call"
              "window-rules"
              "toggle"
            ];
            mediaDashboard = [
              "dms"
              "ipc"
              "call"
              "dash"
              "toggle"
              "media"
            ];
            colorPicker = [
              "dms"
              "ipc"
              "call"
              "color-picker"
              "toggle"
            ];
            nightMode = [
              "dms"
              "ipc"
              "call"
              "night"
              "toggle"
            ];
            idleInhibit = [
              "dms"
              "ipc"
              "call"
              "inhibit"
              "toggle"
            ];
            workspaceRename = [
              "dms"
              "ipc"
              "call"
              "workspace-rename"
              "open"
            ];
            controlCenter = [
              "dms"
              "ipc"
              "call"
              "control-center"
              "toggle"
            ];
            dash = [
              "dms"
              "ipc"
              "call"
              "dash"
              "toggle"
              ""
            ];
          }
        else if desktopShell == "noctalia" then
          {
            launcher = [
              "noctalia"
              "msg"
              "panel-toggle"
              "launcher"
            ];
            launcherBar = [
              "noctalia"
              "msg"
              "panel-toggle"
              "launcher"
            ];
            clipboard = [
              "noctalia"
              "msg"
              "panel-toggle"
              "clipboard"
            ];
            settings = [
              "noctalia"
              "msg"
              "settings-toggle"
            ];
            notifications = [
              "noctalia"
              "msg"
              "panel-toggle"
              "control-center"
              "notifications"
            ];
            notepad = null;
            notepadExpand = null;
            wallpapers = [
              "noctalia"
              "msg"
              "panel-toggle"
              "wallpaper"
            ];
            powerMenu = [
              "noctalia"
              "msg"
              "panel-toggle"
              "session"
            ];
            taskManager = [
              "noctalia"
              "msg"
              "panel-toggle"
              "control-center"
              "system"
            ];
            displayProfile = null;
            lockScreen = [
              "noctalia"
              "msg"
              "session"
              "lock"
            ];
            keybindsHelp = null;
            keybindsHelpMango = null;
            windowRules = null;
            mediaDashboard = null;
            colorPicker = null;
            nightMode = null;
            idleInhibit = null;
            workspaceRename = null;
            controlCenter = [
              "noctalia"
              "msg"
              "panel-toggle"
              "control-center"
            ];
            dash = null;
          }
        else
          {
            launcher = [ "fuzzel" ];
            launcherBar = [ "fuzzel" ];
            clipboard = null;
            settings = null;
            notifications = null;
            notepad = null;
            notepadExpand = null;
            wallpapers = null;
            powerMenu = null;
            taskManager = [ "btop" ];
            displayProfile = null;
            lockScreen = [ "swaylock" ];
            keybindsHelp = null;
            keybindsHelpMango = null;
            windowRules = null;
            mediaDashboard = null;
            colorPicker = null;
            nightMode = null;
            idleInhibit = null;
            workspaceRename = null;
            controlCenter = null;
            dash = null;
          };

      # Screenshots
      screenshots = {
        interactive =
          if desktopShell == "dms" || hdr then
            [
              "shot"
              "area"
            ]
          else if desktopShell == "noctalia" then
            [
              "noctalia"
              "msg"
              "screenshot-region"
            ]
          else
            [
              "grimshot"
              "copy"
              "area"
            ];
        full =
          if desktopShell == "dms" || hdr then
            [
              "shot"
              "full"
            ]
          else if desktopShell == "noctalia" then
            [
              "noctalia"
              "msg"
              "screenshot-fullscreen"
            ]
          else
            [
              "grimshot"
              "copy"
              "screen"
            ];
        window =
          if desktopShell == "dms" || desktopShell == "noctalia" || hdr then
            [
              "shot"
              "window"
            ]
          else
            [
              "grimshot"
              "copy"
              "window"
            ];
      };

      # Audio controls
      audio =
        if desktopShell == "dms" then
          {
            volumeUp = [
              "dms"
              "ipc"
              "call"
              "audio"
              "increment"
              "3"
            ];
            volumeDown = [
              "dms"
              "ipc"
              "call"
              "audio"
              "decrement"
              "3"
            ];
            volumeMute = [
              "dms"
              "ipc"
              "call"
              "audio"
              "mute"
            ];
            micMute = [
              "dms"
              "ipc"
              "call"
              "audio"
              "micmute"
            ];
            mediaPlay = [
              "dms"
              "ipc"
              "call"
              "mpris"
              "playPause"
            ];
            mediaPrev = [
              "dms"
              "ipc"
              "call"
              "mpris"
              "previous"
            ];
            mediaNext = [
              "dms"
              "ipc"
              "call"
              "mpris"
              "next"
            ];
          }
        else if desktopShell == "noctalia" then
          {
            volumeUp = [
              "noctalia"
              "msg"
              "volume-up"
              "3"
            ];
            volumeDown = [
              "noctalia"
              "msg"
              "volume-down"
              "3"
            ];
            volumeMute = [
              "noctalia"
              "msg"
              "volume-mute"
            ];
            micMute = [
              "noctalia"
              "msg"
              "mic-mute"
            ];
            mediaPlay = [
              "noctalia"
              "msg"
              "media"
              "toggle"
            ];
            mediaPrev = [
              "noctalia"
              "msg"
              "media"
              "previous"
            ];
            mediaNext = [
              "noctalia"
              "msg"
              "media"
              "next"
            ];
          }
        else
          {
            volumeUp = [
              "wpctl"
              "set-volume"
              "@DEFAULT_AUDIO_SINK@"
              "5%+"
            ];
            volumeDown = [
              "wpctl"
              "set-volume"
              "@DEFAULT_AUDIO_SINK@"
              "5%-"
            ];
            volumeMute = [
              "wpctl"
              "set-mute"
              "@DEFAULT_AUDIO_SINK@"
              "toggle"
            ];
            micMute = [
              "wpctl"
              "set-mute"
              "@DEFAULT_AUDIO_SOURCE@"
              "toggle"
            ];
            mediaPlay = [
              "playerctl"
              "play-pause"
            ];
            mediaPrev = [
              "playerctl"
              "previous"
            ];
            mediaNext = [
              "playerctl"
              "next"
            ];
          };

      # Brightness controls
      brightness =
        if desktopShell == "dms" then
          {
            brightnessUp = [
              "dms"
              "ipc"
              "call"
              "brightness"
              "increment"
              "5"
              ""
            ];
            brightnessDown = [
              "dms"
              "ipc"
              "call"
              "brightness"
              "decrement"
              "5"
              ""
            ];
          }
        else if desktopShell == "noctalia" then
          {
            brightnessUp = [
              "noctalia"
              "msg"
              "brightness-up"
              "5%"
            ];
            brightnessDown = [
              "noctalia"
              "msg"
              "brightness-down"
              "5%"
            ];
          }
        else
          {
            brightnessUp = [
              "brightnessctl"
              "set"
              "+5%"
            ];
            brightnessDown = [
              "brightnessctl"
              "set"
              "5%-"
            ];
          };
    in
    {
      inherit
        terminalCommand
        emojiCommand
        appCommands
        screenshots
        audio
        brightness
        ;
    };
}
