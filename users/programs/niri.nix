{
  lib,
  pkgs,
  osConfig,
  desktopShell ? osConfig.desktop.shell,
  inputs,
  ...
}:

let
  monitors = osConfig.desktop.monitors;

  generatedBinds = ''
    binds {
  ''
  + lib.optionalString (desktopShell == "dms") ''
    Mod+Space hotkey-overlay-title="Run an Application: dms" { spawn "dms" "ipc" "call" "spotlight" "toggle"; }
  ''
  + ''
      Mod+T { spawn "kitty"; }
      Mod+Period { spawn "smile"; }
      Print { spawn "ksnip" "-r"; }
      F12 { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
    }
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

  configKdl = pkgs.runCommand "niri-config.kdl" { } ''
    cp ${inputs.thefiles}/.config/niri/config.kdl "$out"
    chmod +w "$out"
    printf '\ninclude "nix-generated-binds.kdl"\ninclude "nix-generated-outputs.kdl"\n' >> "$out"
  '';
in
{
  xdg.enable = true;
  xdg.configFile = {
    "niri/nix-generated-binds.kdl".text = generatedBinds;
    "niri/nix-generated-outputs.kdl".text = outputsKdl;
    "niri/config.kdl".source = configKdl;
  };
}
