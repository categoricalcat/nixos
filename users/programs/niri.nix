{
  lib,
  osConfig,
  desktopShell ? osConfig.desktop.shell,
  ...
}:

let
  monitors = osConfig.desktop.monitors;

  generatedBinds =
    lib.optionalString (desktopShell == "dms") ''
      Mod+Space hotkey-overlay-title="Run an Application: dms" { spawn "dms" "ipc" "call" "spotlight" "toggle"; }
    ''
    + ''
      Mod+T { spawn "kitty"; }
      Mod+Period { spawn "smile"; }
      Print { spawn "ksnip" "-r"; }
      F12 { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
    '';

  generateOutput = m: ''
    output "${m.name}" {
      ${lib.optionalString (m.mode != null) ''mode "${m.mode}"''}
      scale ${toString m.scale}
      transform "${m.transform}"
      ${lib.optionalString (
        m.position != null
      ) "position x=${toString m.position.x} y=${toString m.position.y}"}
    }
  '';

  outputsKdl = lib.concatMapStringsSep "\n" generateOutput monitors;

  configKdl =
    builtins.replaceStrings
      [
        "// @nix-generated-binds"
        "// @nix-generated-outputs"
      ]
      [
        generatedBinds
        outputsKdl
      ]
      (builtins.readFile ./niri/config.kdl);
in
{
  xdg.configFile."niri/config.kdl".text = configKdl;
}
