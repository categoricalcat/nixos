{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    attrValues
    concatMap
    mkOption
    types
    ;

  prefixes = attrValues config.yi.audio.pluginPrefixes;

  # The bridge shares wine-launcher's Wine, so the host, the chainloader and the
  # prefixes all speak one wineserver protocol version.
  inherit (import ./wine-launcher.nix { inherit pkgs; }) yabridge yabridgectl;
in
{
  # Each prefix owner (amplitube.nix, toontrack.nix) declares its own entry, so
  # the prefix path and its VST3 directory are authored once and only consumed here.
  options.yi.audio.pluginPrefixes = mkOption {
    type = types.attrsOf (
      types.submodule {
        options = {
          vst3Dir = mkOption {
            type = types.path;
            description = "Windows VST3 directory inside the prefix; yabridgectl bridges what it finds here.";
          };
          watch = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = ''
              Paths relative to `vst3Dir` whose change signals a finished install.
              The bundle folder appears before the installer finishes; its binary
              lands when the copy completes.
            '';
          };
        };
      }
    );
    default = { };
    description = "Wine prefixes holding Windows VST3 plugins, one entry per prefix.";
  };

  config = {
    home.packages = [
      yabridge
      yabridgectl
    ];

    xdg.configFile."yabridgectl/config.toml".source =
      (pkgs.formats.toml { }).generate "yabridgectl.toml"
        {
          plugin_dirs = map (p: p.vst3Dir) prefixes;
          yabridge_home = "${yabridge}/lib";
          # Verification records the Wine version in this file, which is read-only
          no_verify = true;
        };

    systemd.user = {
      services.yabridge-sync = {
        Unit = {
          Description = "Bridge Windows VST3 plugins from the Wine prefixes";
          # yabridgectl skips missing plugin dirs, so no ConditionPath is needed
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${lib.getExe yabridgectl} sync";
        };
        Install.WantedBy = [ "default.target" ];
      };

      paths.yabridge-sync = {
        Unit.Description = "Watch the Wine prefixes for VST3 installs";
        Path.PathChanged = [
          "${config.xdg.configHome}/yabridgectl/config.toml"
        ]
        ++ concatMap (p: [ p.vst3Dir ] ++ map (w: "${p.vst3Dir}/${w}") p.watch) prefixes;
        Install.WantedBy = [ "default.target" ];
      };
    };
  };
}
