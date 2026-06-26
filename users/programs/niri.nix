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
  + lib.optionalString (desktopShell == "noctalia") ''
    Mod+Space hotkey-overlay-title="Run an Application: noctalia" { spawn "noctalia" "msg" "panel-toggle" "launcher"; }
  ''
  + ''
      Mod+T { spawn "kitty"; }
      Mod+Period { spawn "smile"; }
      Print { screenshot; }
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

  niriConfigDir = pkgs.runCommand "niri-config" { } ''
    cp -r ${inputs.thefiles}/.config/niri "$out"
    chmod -R +w "$out"
    printf '\ninclude "nix-generated-binds.kdl"\ninclude "nix-generated-outputs.kdl"\n' >> "$out/config.kdl"
  '';
in
{
  xdg.enable = true;
  home.file.".config/niri".source = lib.mkForce niriConfigDir;
  xdg.configFile = {
    "niri/nix-generated-binds.kdl".text = generatedBinds;
    "niri/nix-generated-outputs.kdl".text = outputsKdl;
  };
}
