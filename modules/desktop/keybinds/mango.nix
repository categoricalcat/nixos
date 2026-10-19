{
  lib,
  bindings,
  shellCommands,
  ...
}:

{
  # Generate Mango config file string from source of truth
  generateMangoConfig =
    {
      terminalCommand ? "kitty",
      desktopShell ? "dms",
      emojiCommand ? "smile",
      hdr ? false,
    }:
    let
      cmds = shellCommands.getShellCommands {
        inherit
          terminalCommand
          desktopShell
          emojiCommand
          hdr
          ;
      };

      spawnCmd =
        cmd:
        if cmd == null || cmd == [ ] then
          ""
        else
          "spawn,${lib.concatStringsSep " " (map (a: if a == "" then "\"\"" else a) cmd)}";

      bind =
        desc: key: cmd:
        if cmd == "" || cmd == null then "" else "# ${desc}\nbind=${key},${cmd}";
      bindList =
        def: cmd:
        if cmd == "" || cmd == null then
          ""
        else
          lib.concatMapStringsSep "\n" (k: bind def.description k cmd) def.keys;

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
      # Default keybinds (MangoWM) — generated from modules/desktop/keybinds
      # Format: bind=MODS,key,action[,args]
      # Put bind descriptions above bind lines; inline # comments break Mango spawn args.

      # === Application Launchers ===
      ${bindList bindings.terminal (spawnCmd [ terminalCommand ])}
      ${bindList bindings.launcher (spawnCmd cmds.appCommands.launcher)}
      ${bindList bindings.launcherBar (spawnCmd cmds.appCommands.launcherBar)}
      ${bindList bindings.clipboard (spawnCmd cmds.appCommands.clipboard)}
      ${bindList bindings.emojiPicker (spawnCmd [ emojiCommand ])}
      ${bindList bindings.taskManager (spawnCmd cmds.appCommands.taskManager)}
      ${bindList bindings.settings (spawnCmd cmds.appCommands.settings)}
      ${bindList bindings.notifications (spawnCmd cmds.appCommands.notifications)}
      ${bindList bindings.notepad (spawnCmd cmds.appCommands.notepad)}
      ${bindList bindings.wallpapers (spawnCmd cmds.appCommands.wallpapers)}
      ${bindList bindings.powerMenu (spawnCmd cmds.appCommands.powerMenu)}
      ${bindList bindings.displayProfile (spawnCmd cmds.appCommands.displayProfile)}

      # === Cheat sheet ===
      ${bindList bindings.keybindsHelp (spawnCmd cmds.appCommands.keybindsHelpMango)}

      # === Security ===
      ${bindList bindings.lockScreen (spawnCmd cmds.appCommands.lockScreen)}

      # === Window Rules ===
      ${bindList bindings.windowRules (spawnCmd cmds.appCommands.windowRules)}

      # === Screenshots ===
      ${bindList bindings.screenshotInteractive (spawnCmd cmds.screenshots.interactive)}
      ${bindList bindings.screenshotFull (spawnCmd cmds.screenshots.full)}
      ${bindList bindings.screenshotWindow (spawnCmd cmds.screenshots.window)}

      # === Audio Controls ===
      ${bindList bindings.volumeUp (spawnCmd cmds.audio.volumeUp)}
      ${bindList bindings.volumeDown (spawnCmd cmds.audio.volumeDown)}
      ${bindList bindings.volumeMute (spawnCmd cmds.audio.volumeMute)}
      ${bindList bindings.micMute (spawnCmd cmds.audio.micMute)}
      ${bindList bindings.mediaPlay (spawnCmd cmds.audio.mediaPlay)}
      ${bindList bindings.mediaPrev (spawnCmd cmds.audio.mediaPrev)}
      ${bindList bindings.mediaNext (spawnCmd cmds.audio.mediaNext)}

      # === Brightness Controls ===
      ${bindList bindings.brightnessUp (spawnCmd cmds.brightness.brightnessUp)}
      ${bindList bindings.brightnessDown (spawnCmd cmds.brightness.brightnessDown)}

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
      ${lib.concatMapStringsSep "\n" (k: "axisbind=${k},focusdir,left") bindings.scrollFocusPrev.keys}
      ${lib.concatMapStringsSep "\n" (k: "axisbind=${k},focusdir,right") bindings.scrollFocusNext.keys}

      # === Layout ===
      ${bindList bindings.cycleWindowWidth "switch_proportion_preset,next"}
      ${bindList bindings.switchLayout "switch_layout"}
      ${bindList bindings.cycleKeyboardLayout "switch_keyboard_layout"}
      ${bindList bindings.increaseGaps "incgaps,1"}
      ${bindList bindings.decreaseGaps "incgaps,-1"}

      # === Tags (1-9) ===
      ${workspaceBinds}

      # === Touchpad Gestures ===
      gesturebind=none,left,3,focusdir,right
      gesturebind=none,right,3,focusdir,left
      gesturebind=none,up,3,viewtoright
      gesturebind=none,down,3,viewtoleft
      gesturebind=none,up,4,toggleoverview
      gesturebind=none,down,4,toggleoverview
    '';
}
