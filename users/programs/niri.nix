{
  lib,
  pkgs,
  desktopShell ? "none",
  monitors ? [ ],
  inputs,
  ...
}:

let
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
  generatedBindsFile = pkgs.writeText "niri-generated-binds.kdl" generatedBinds;
  outputsKdlFile = pkgs.writeText "niri-generated-outputs.kdl" outputsKdl;

  niriConfigDir = pkgs.runCommand "niri-config" { } ''
    cp -r ${../assets/dotfiles/niri} "$out"
    chmod -R +w "$out"
    cp ${generatedBindsFile} "$out/nix-generated-binds.kdl"
    cp ${outputsKdlFile} "$out/nix-generated-outputs.kdl"
    printf '\ninclude "nix-generated-binds.kdl"\ninclude "nix-generated-outputs.kdl"\n' >> "$out/config.kdl"

    mkdir -p "$out/dms"
    cp ${inputs.dms.outPath}/core/internal/config/embedded/niri-alttab.kdl "$out/dms/alttab.kdl"
    sed 's/{{TERMINAL_COMMAND}}/kitty/g' ${inputs.dms.outPath}/core/internal/config/embedded/niri-binds.kdl > "$out/dms/binds.kdl"
    cp ${inputs.dms.outPath}/core/internal/config/embedded/niri-colors.kdl "$out/dms/colors.kdl"
    cp ${inputs.dms.outPath}/core/internal/config/embedded/niri-layout.kdl "$out/dms/layout.kdl"
    touch "$out/dms/outputs.kdl"
    touch "$out/dms/cursor.kdl"
    touch "$out/dms/windowrules.kdl"
  '';
in
{
  xdg.enable = true;
  home.file.".config/niri".source = lib.mkForce niriConfigDir;
}
