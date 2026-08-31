{ lib }:

let
  # Centralized Desktop Keybindings (Source of Truth)
  # All baseline desktop shortcuts are preserved; Emacs-style bindings are appended.
  # Conflicting key combinations include both variants with one commented.
  bindings = {
    # === Application Launchers ===
    terminal = {
      description = "Open Terminal";
      keys = [
        "SUPER,t"
        "SUPER,Return"
      ];
    };
    launcher = {
      description = "Application Launcher (Spotlight)";
      keys = [
        "SUPER,space"
      ];
    };
    launcherBar = {
      description = "Spotlight Bar";
      keys = [
        "ALT,space"
      ];
    };
    clipboard = {
      description = "Clipboard Manager";
      keys = [
        "SUPER,v"
      ];
    };
    taskManager = {
      description = "Task Manager";
      keys = [
        "SUPER,m"
        "CTRL+ALT,Delete"
      ];
    };
    settings = {
      description = "Desktop Settings";
      keys = [
        "SUPER,comma"
      ];
    };
    notifications = {
      description = "Notification Center";
      keys = [
        "SUPER,n"
      ];
    };
    notepad = {
      description = "Notepad";
      keys = [
        "SUPER+SHIFT,n"
      ];
    };
    wallpapers = {
      description = "Browse Wallpapers";
      keys = [
        "SUPER,y"
      ];
    };
    powerMenu = {
      description = "Power Menu";
      keys = [
        "SUPER,x"
      ];
    };
    displayProfile = {
      description = "Cycle Display Profile";
      keys = [
        "SUPER,p"
      ];
    };
    lockScreen = {
      description = "Lock Screen";
      keys = [
        "SUPER+ALT,l"
      ];
    };
    keybindsHelp = {
      description = "Keyboard Shortcuts Cheat Sheet";
      keys = [
        "SUPER+SHIFT,slash"
      ];
    };
    windowRules = {
      description = "Window Rules Manager";
      keys = [
        "SUPER+SHIFT,w"
      ];
    };

    # === Window Management ===
    closeWindow = {
      description = "Close Window (Baseline Super+Q & Emacs Super+0 / Super+K)";
      keys = [
        "SUPER,q"
        "SUPER,0"
      ];
    };
    fullscreen = {
      description = "Toggle Fullscreen";
      keys = [
        "SUPER,f"
      ];
    };
    maximize = {
      description = "Toggle Maximize";
      keys = [
        "SUPER,a"
      ];
    };
    toggleFloating = {
      description = "Toggle Floating Window";
      keys = [
        "SUPER+SHIFT,space"
      ];
    };
    toggleOverview = {
      description = "Toggle Overview";
      keys = [
        "SUPER,o"
        "ALT,Tab"
      ];
    };
    quitSession = {
      description = "Exit Compositor";
      keys = [
        "SUPER+SHIFT,e"
      ];
    };

    # === Emacs Window Splits (Non-destructive Super+Alt combinations) ===
    splitBelow = {
      description = "Split Window Below (Emacs C-x 2)";
      keys = [
        "SUPER+ALT,2"
      ];
    };
    splitRight = {
      description = "Split Window Right (Emacs C-x 3)";
      keys = [
        "SUPER+ALT,3"
      ];
    };

    # === Focus Navigation ===
    focusLeft = {
      description = "Focus Left (Arrows, Vim H & Emacs B)";
      keys = [
        "SUPER,Left"
        "SUPER,H"
        "SUPER,b"
      ];
    };
    focusRight = {
      description = "Focus Right (Arrows & Vim L)";
      keys = [
        "SUPER,Right"
        "SUPER,L"
      ];
    };
    focusUp = {
      description = "Focus Up (Arrows & Vim K)";
      keys = [
        "SUPER,Up"
        "SUPER,K"
      ];
    };
    focusDown = {
      description = "Focus Down (Arrows & Vim J)";
      keys = [
        "SUPER,Down"
        "SUPER,J"
      ];
    };
    focusNext = {
      description = "Focus Next in Stack (Emacs C-x o / Other Window)";
      keys = [
        "SUPER,Tab"
      ];
    };
    focusPrev = {
      description = "Focus Previous in Stack";
      keys = [
        "SUPER+SHIFT,Tab"
      ];
    };

    # === Window Movement ===
    moveLeft = {
      description = "Swap Window Left (Arrows, Vim H & Emacs B)";
      keys = [
        "SUPER+SHIFT,Left"
        "SUPER+SHIFT,H"
        "SUPER+SHIFT,b"
      ];
    };
    moveRight = {
      description = "Swap Window Right (Arrows, Vim L & Emacs F)";
      keys = [
        "SUPER+SHIFT,Right"
        "SUPER+SHIFT,L"
        "SUPER+SHIFT,f"
      ];
    };
    moveUp = {
      description = "Swap Window Up (Arrows, Vim K & Emacs P)";
      keys = [
        "SUPER+SHIFT,Up"
        "SUPER+SHIFT,K"
        "SUPER+SHIFT,p"
      ];
    };
    moveDown = {
      description = "Swap Window Down (Arrows & Vim J)";
      keys = [
        "SUPER+SHIFT,Down"
        "SUPER+SHIFT,J"
      ];
    };

    # === Monitor Navigation ===
    focusMonitorLeft = {
      description = "Focus Monitor Left (Arrows & Emacs B)";
      keys = [
        "SUPER+ALT,Left"
        "SUPER+ALT,b"
      ];
    };
    focusMonitorRight = {
      description = "Focus Monitor Right (Arrows & Emacs F)";
      keys = [
        "SUPER+ALT,Right"
        "SUPER+ALT,f"
      ];
    };
    focusMonitorUp = {
      description = "Focus Monitor Up (Arrows & Emacs P)";
      keys = [
        "SUPER+ALT,Up"
        "SUPER+ALT,p"
      ];
    };
    focusMonitorDown = {
      description = "Focus Monitor Down (Arrows & Emacs N)";
      keys = [
        "SUPER+ALT,Down"
        "SUPER+ALT,n"
      ];
    };
    moveMonitorLeft = {
      description = "Move Window to Monitor Left (Arrows & Emacs B)";
      keys = [
        "SUPER+ALT+SHIFT,Left"
        "SUPER+ALT+SHIFT,b"
      ];
    };
    moveMonitorRight = {
      description = "Move Window to Monitor Right (Arrows & Emacs F)";
      keys = [
        "SUPER+ALT+SHIFT,Right"
        "SUPER+ALT+SHIFT,f"
      ];
    };
    moveMonitorUp = {
      description = "Move Window to Monitor Up (Arrows & Emacs P)";
      keys = [
        "SUPER+ALT+SHIFT,Up"
        "SUPER+ALT+SHIFT,p"
      ];
    };
    moveMonitorDown = {
      description = "Move Window to Monitor Down (Arrows & Emacs N)";
      keys = [
        "SUPER+ALT+SHIFT,Down"
        "SUPER+ALT+SHIFT,n"
      ];
    };

    # === Mouse & Interactive Controls ===
    mouseMove = {
      description = "Move Window with Mouse (Drag)";
      keys = [
        "SUPER,btn_left"
      ];
    };
    mouseResize = {
      description = "Resize Window with Mouse (Drag)";
      keys = [
        "SUPER,btn_right"
      ];
    };
    scrollFocusPrev = {
      description = "Focus Previous Window (Scroll Up)";
      keys = [
        "SUPER,UP"
      ];
    };
    scrollFocusNext = {
      description = "Focus Next Window (Scroll Down)";
      keys = [
        "SUPER,DOWN"
      ];
    };

    # === Layout ===
    cycleWindowWidth = {
      description = "Cycle Preset Window / Column Width (Niri & Mango Scroller)";
      keys = [
        "SUPER,r"
      ];
    };
    switchLayout = {
      description = "Cycle Layout";
      keys = [
        "SUPER+ALT,j"
      ];
    };
    cycleKeyboardLayout = {
      description = "Cycle Keyboard Layout";
      keys = [
        "SUPER+ALT,space"
      ];
    };
    increaseGaps = {
      description = "Increase Gaps";
      keys = [
        "SUPER+SHIFT,equal"
      ];
    };
    decreaseGaps = {
      description = "Decrease Gaps";
      keys = [
        "SUPER+SHIFT,minus"
      ];
    };

    # === Screenshots ===
    screenshotInteractive = {
      description = "Screenshot: Interactive";
      keys = [
        "none,Print"
      ];
    };
    screenshotFull = {
      description = "Screenshot: Full Screen";
      keys = [
        "CTRL,Print"
      ];
    };
    screenshotWindow = {
      description = "Screenshot: Window";
      keys = [
        "ALT,Print"
      ];
    };

    # === Audio Controls ===
    volumeUp = {
      description = "Raise Volume";
      keys = [
        "none,XF86AudioRaiseVolume"
      ];
    };
    volumeDown = {
      description = "Lower Volume";
      keys = [
        "none,XF86AudioLowerVolume"
      ];
    };
    volumeMute = {
      description = "Mute Audio";
      keys = [
        "none,XF86AudioMute"
      ];
    };
    micMute = {
      description = "Mute Microphone";
      keys = [
        "none,XF86AudioMicMute"
        "none,F12"
      ];
    };
    mediaPlay = {
      description = "Play Media";
      keys = [
        "none,XF86AudioPlay"
      ];
    };
    mediaPause = {
      description = "Pause Media";
      keys = [
        "none,XF86AudioPause"
      ];
    };
    mediaPrev = {
      description = "Previous Track";
      keys = [
        "none,XF86AudioPrev"
      ];
    };
    mediaNext = {
      description = "Next Track";
      keys = [
        "none,XF86AudioNext"
      ];
    };

    # === Brightness Controls ===
    brightnessUp = {
      description = "Brightness Up";
      keys = [
        "none,XF86MonBrightnessUp"
      ];
    };
    brightnessDown = {
      description = "Brightness Down";
      keys = [
        "none,XF86MonBrightnessDown"
      ];
    };
  };

  # Generate Mango config file string from source of truth
  generateMangoConfig =
    {
      terminalCommand ? "kitty",
      desktopShell ? "dms",
    }:
    let
      bind =
        desc: key: cmd:
        "# ${desc}\nbind=${key},${cmd}";
      bindList = def: cmd: lib.concatMapStringsSep "\n" (k: bind def.description k cmd) def.keys;

      appCmd = cmd: if desktopShell == "dms" then "spawn,dms ipc call ${cmd}" else "spawn,${cmd}";

      workspaceBinds = lib.concatStringsSep "\n" (
        map (n: ''
          # === Tags (${toString n}): view tag ===
          bind=SUPER,${toString n},view,${toString n}
          # === Tags (${toString n}): move focused window to tag ===
          bind=SUPER+SHIFT,${toString n},tag,${toString n}
        '') (lib.range 1 9)
      );
    in
    ''
      # DMS default keybinds (MangoWM) — generated from modules/desktop/keybinds.nix
      # Format: bind=MODS,key,action[,args]
      # Put bind descriptions above bind lines; inline # comments break Mango spawn args.

      # === Application Launchers ===
      ${bindList bindings.terminal "spawn,${terminalCommand}"}
      ${bindList bindings.launcher (appCmd "spotlight toggle")}
      ${bindList bindings.launcherBar (appCmd "spotlight-bar toggle")}
      ${bindList bindings.clipboard (appCmd "clipboard toggle")}
      ${bindList bindings.taskManager (appCmd "processlist focusOrToggle")}
      ${bindList bindings.settings (appCmd "settings focusOrToggle")}
      ${bindList bindings.notifications (appCmd "notifications toggle")}
      ${bindList bindings.notepad (appCmd "notepad toggle")}
      ${bindList bindings.wallpapers (appCmd "dash toggle wallpaper")}
      ${bindList bindings.powerMenu (appCmd "powermenu toggle")}
      ${bindList bindings.displayProfile (
        if desktopShell == "dms" then "spawn,dms ipc outputs cycleProfile" else ""
      )}

      # === Cheat sheet ===
      ${bindList bindings.keybindsHelp (appCmd "keybinds toggle mangowc")}

      # === Security ===
      ${bindList bindings.lockScreen (
        if desktopShell == "dms" then "spawn,dms ipc call lock lock" else "spawn,swaylock"
      )}

      # === Window Rules ===
      ${bindList bindings.windowRules (appCmd "window-rules toggle")}

      # === Screenshots ===
      ${bindList bindings.screenshotInteractive (
        if desktopShell == "dms" then "spawn,dms screenshot" else "spawn,grimshot copy area"
      )}
      ${bindList bindings.screenshotFull (
        if desktopShell == "dms" then "spawn,dms screenshot full" else "spawn,grimshot copy screen"
      )}
      ${bindList bindings.screenshotWindow (
        if desktopShell == "dms" then "spawn,dms screenshot window" else "spawn,grimshot copy window"
      )}

      # === Audio Controls ===
      ${bindList bindings.volumeUp (
        if desktopShell == "dms" then
          "spawn,dms ipc call audio increment 3"
        else
          "spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
      )}
      ${bindList bindings.volumeDown (
        if desktopShell == "dms" then
          "spawn,dms ipc call audio decrement 3"
        else
          "spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      )}
      ${bindList bindings.volumeMute (
        if desktopShell == "dms" then
          "spawn,dms ipc call audio mute"
        else
          "spawn,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      )}
      ${bindList bindings.micMute (
        if desktopShell == "dms" then
          "spawn,dms ipc call audio micmute"
        else
          "spawn,wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
      )}
      ${bindList bindings.mediaPlay (
        if desktopShell == "dms" then "spawn,dms ipc call mpris playPause" else "spawn,playerctl play-pause"
      )}
      ${bindList bindings.mediaPause (
        if desktopShell == "dms" then "spawn,dms ipc call mpris playPause" else "spawn,playerctl play-pause"
      )}
      ${bindList bindings.mediaPrev (
        if desktopShell == "dms" then "spawn,dms ipc call mpris previous" else "spawn,playerctl previous"
      )}
      ${bindList bindings.mediaNext (
        if desktopShell == "dms" then "spawn,dms ipc call mpris next" else "spawn,playerctl next"
      )}

      # === Brightness Controls ===
      ${bindList bindings.brightnessUp (
        if desktopShell == "dms" then
          "spawn,dms ipc call brightness increment 5"
        else
          "spawn,brightnessctl set +5%"
      )}
      ${bindList bindings.brightnessDown (
        if desktopShell == "dms" then
          "spawn,dms ipc call brightness decrement 5"
        else
          "spawn,brightnessctl set 5%-"
      )}

      # === Window Management ===
      ${bindList bindings.closeWindow "killclient,"}
      # Emacs kill buffer alias (conflicts with Vim focus up Super+K; commented out):
      # bind=SUPER,k,killclient,
      ${bindList bindings.fullscreen "togglefullscreen,"}
      ${bindList bindings.maximize "togglemaximizescreen,"}
      # Emacs maximize window alias (conflicts with view tag 1 Super+1; commented out):
      # bind=SUPER,1,togglemaximizescreen,
      ${bindList bindings.splitBelow "scroller_stack,down"}
      ${bindList bindings.splitRight "scroller_stack,right"}
      ${bindList bindings.toggleFloating "togglefloating,"}
      ${bindList bindings.toggleOverview "toggleoverview"}
      ${bindList bindings.quitSession "quit,"}

      # === Focus Navigation ===
      ${bindList bindings.focusNext "focusstack,next"}
      ${bindList bindings.focusPrev "focusstack,prev"}
      ${bindList bindings.focusLeft "focusdir,left"}
      ${bindList bindings.focusRight "focusdir,right"}
      # Emacs forward focus alias (conflicts with fullscreen Super+F; commented out):
      # bind=SUPER,f,focusdir,right
      ${bindList bindings.focusUp "focusdir,up"}
      # Emacs previous focus alias (conflicts with display profile Super+P; commented out):
      # bind=SUPER,p,focusdir,up
      ${bindList bindings.focusDown "focusdir,down"}
      # Emacs next focus alias (conflicts with notification toggle Super+N; commented out):
      # bind=SUPER,n,focusdir,down

      # === Window Movement ===
      ${bindList bindings.moveLeft "exchange_client,left"}
      ${bindList bindings.moveRight "exchange_client,right"}
      ${bindList bindings.moveUp "exchange_client,up"}
      ${bindList bindings.moveDown "exchange_client,down"}
      # Emacs down swap alias (conflicts with notepad toggle Super+Shift+N; commented out):
      # bind=SUPER+SHIFT,n,exchange_client,down

      # === Monitor Navigation ===
      ${bindList bindings.focusMonitorLeft "focusmon,left"}
      ${bindList bindings.focusMonitorRight "focusmon,right"}
      ${bindList bindings.focusMonitorUp "focusmon,up"}
      ${bindList bindings.focusMonitorDown "focusmon,down"}
      ${bindList bindings.moveMonitorLeft "tagmon,left"}
      ${bindList bindings.moveMonitorRight "tagmon,right"}
      ${bindList bindings.moveMonitorUp "tagmon,up"}
      ${bindList bindings.moveMonitorDown "tagmon,down"}

      # === Mouse Bindings ===
      ${lib.concatMapStringsSep "\n" (k: "mousebind=${k},moveresize,curmove") bindings.mouseMove.keys}
      ${lib.concatMapStringsSep "\n" (k: "mousebind=${k},moveresize,curresize") bindings.mouseResize.keys}

      # === Mouse Wheel / Axis Bindings ===
      ${lib.concatMapStringsSep "\n" (k: "axisbind=${k},focusstack,prev") bindings.scrollFocusPrev.keys}
      ${lib.concatMapStringsSep "\n" (k: "axisbind=${k},focusstack,next") bindings.scrollFocusNext.keys}

      # === Layout ===
      ${bindList bindings.cycleWindowWidth "switch_proportion_preset"}
      ${bindList bindings.switchLayout "switch_layout"}
      ${bindList bindings.cycleKeyboardLayout "switch_keyboard_layout"}
      ${bindList bindings.increaseGaps "incgaps,1"}
      ${bindList bindings.decreaseGaps "incgaps,-1"}

      # === Tags (1-9) ===
      ${workspaceBinds}

      # === Touchpad Gestures ===
      gesturebind=none,right,3,viewtoleft_have_client
      gesturebind=none,left,3,viewtoright_have_client
      gesturebind=none,up,4,toggleoverview
      gesturebind=none,down,4,toggleoverview
    '';
in
{
  inherit bindings generateMangoConfig;
}
