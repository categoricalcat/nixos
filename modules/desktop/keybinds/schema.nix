_:

{
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
        "ALT,space"
      ];
    };
    launcherBar = {
      description = "Spotlight Bar";
      keys = [
        "SUPER,space"
      ];
    };
    clipboard = {
      description = "Clipboard Manager";
      keys = [
        "SUPER,v"
      ];
    };
    emojiPicker = {
      description = "Emoji Picker";
      keys = [
        "SUPER,period"
      ];
    };
    taskManager = {
      description = "Task Manager";
      keys = [
        "SUPER,m"
        "CTRL+ALT,m"
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
    mediaDashboard = {
      description = "Media Dashboard";
      keys = [
        "SUPER,m"
      ];
    };
    colorPicker = {
      description = "Color Picker";
      keys = [
        "SUPER+SHIFT,c"
      ];
    };
    nightMode = {
      description = "Night Mode";
      keys = [
        "SUPER+ALT,n"
      ];
    };
    idleInhibit = {
      description = "Idle Inhibit";
      keys = [
        "SUPER+ALT,i"
      ];
    };
    workspaceRename = {
      description = "Rename Workspace";
      keys = [
        "SUPER+ALT,r"
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
      description = "Toggle Maximize (Super+A on Mango; Super+Shift+F on Niri)";
      keys = [
        "SUPER,a"
      ];
    };
    toggleFloating = {
      description = "Toggle Floating Window";
      keys = [
        "SUPER+SHIFT,space"
        "SUPER+SHIFT,t"
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
        "CTRL+ALT,Delete"
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
        "SUPER+SHIFT,s"
        "none,XF86Launch1"
      ];
    };
    screenshotFull = {
      description = "Screenshot: Full Screen";
      keys = [
        "CTRL,Print"
        "CTRL,XF86Launch1"
      ];
    };
    screenshotWindow = {
      description = "Screenshot: Window";
      keys = [
        "ALT,Print"
        "ALT,XF86Launch1"
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
}
