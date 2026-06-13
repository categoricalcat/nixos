{
  lib,
  osConfig,
  inputs,
  ...
}:

let
  cfg = osConfig.desktop.monitors;

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

  outputsKdl = lib.concatStringsSep "\n" (map generateOutput cfg);
in
{
  xdg.configFile."niri/config.kdl".text =
    let
      baseKdl = builtins.readFile "${inputs.thefiles}/.config/niri/config.kdl";
      patchedKdl =
        builtins.replaceStrings
          [ "binds {" ]
          [
            ''
              binds {
                ''${launcherBind}
                Mod+T { spawn "kitty"; }
                Mod+Period { spawn "smile"; }
                Print { spawn "ksnip" "-r"; }
                F12 { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
            ''
          ]
          (
            lib.concatStringsSep "\n" (
              lib.filter (
                line:
                !(lib.hasInfix "Mod+T" line && lib.hasInfix "alacritty" line)
                && !(lib.hasInfix "Mod+Space" line && lib.hasInfix "spotlight" line)
              ) (lib.splitString "\n" baseKdl)
            )
          );
    in
    ''
      ${patchedKdl}
      ${outputsKdl}
    '';
}
