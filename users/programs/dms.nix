{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:

let
  themeAssets = import ../../modules/theme-assets.nix { inherit inputs pkgs; };
  colors = import ../../modules/theme.nix;
  c = name: "#${colors.${name}}";
  dmsSettings = builtins.fromJSON (builtins.readFile ./dms/settings.json);
  inherit (fromTOML (builtins.readFile ./noctalia/config.toml)) nightlight;
  dmsNightMode = {
    nightModeEnabled = nightlight.enabled;
    nightModeAutoEnabled = !nightlight.force;
    nightModeAutoMode = "location";
    nightModeTemperature = nightlight.temperature_night;
    nightModeHighTemperature = nightlight.temperature_day;
  };
  animRate = config.desktop.animationRate;
  scale = ms: if animRate <= 0.0 then 0 else lib.trivial.max 1 (builtins.floor (ms * animRate));
  yimokaTheme = {
    dark = {
      name = "Yimoka Dark";
      primary = c "base0D";
      primaryText = c "base00";
      primaryContainer = c "base02";
      secondary = c "base0E";
      secondaryContainer = c "base02";
      tertiary = c "base0C";
      tertiaryContainer = c "base02";
      surface = c "base00";
      surfaceText = c "base05";
      surfaceVariant = c "base01";
      surfaceVariantText = c "base05";
      surfaceTint = c "base0D";
      background = c "base00";
      backgroundText = c "base05";
      outline = c "base03";
      outlineVariant = c "base04";
      surfaceContainerLowest = c "base00";
      surfaceContainerLow = c "base01";
      surfaceContainer = c "base01";
      surfaceContainerHigh = c "base02";
      surfaceContainerHighest = c "base03";
      surfaceBright = c "base03";
      surfaceDim = c "base00";
      error = c "base08";
      warning = c "base0A";
      success = c "base0B";
      info = c "base0D";
      matugen_type = "scheme-expressive";
    };
  };
in
{
  systemd.user.services.awww = {
    Unit = {
      Description = "awww wallpaper daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.awww}/bin/awww-daemon";
      Restart = "on-failure";
      RestartSec = 1;
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Nix sets every theme-derived DMS key; the Stylix target writes the same keys.
  stylix.targets.dank-material-shell.enable = false;

  home = {
    sessionVariables = {
      QS_ICON_THEME = themeAssets.icons.dark;
    };

    activation.mergeDmsNightMode = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      merge_dms_night_mode() {
        local target="${config.xdg.stateHome}/dms/session.json"
        local tmp
        mkdir -p "$(dirname "$target")"
        [ -s "$target" ] || echo '{}' > "$target"
        tmp=$(mktemp "$target.XXXXXX")
        if ${lib.getExe pkgs.jq} --argjson nightMode ${lib.escapeShellArg (builtins.toJSON dmsNightMode)} '
          . + $nightMode +
          (if (.latitude == null or .latitude == 0) and .weatherCoordinates and (.weatherCoordinates | contains(",")) then
             (.weatherCoordinates | split(",")) as $c |
             {latitude: ($c[0] | tonumber), longitude: ($c[1] | tonumber), nightModeUseIPLocation: false}
           elif (.latitude != null and .latitude != 0) then
             {nightModeUseIPLocation: false}
           else
             {}
           end)
        ' "$target" > "$tmp"; then
          mv "$tmp" "$target"
        else
          rm -f "$tmp"
          echo "mergeDmsNightMode: $target is not valid JSON, skipping" >&2
        fi
      }
      run merge_dms_night_mode
    '';
  };

  systemd.user.services.dms = {
    Service = {
      Environment = [
        "XDG_DATA_DIRS=/etc/profiles/per-user/${config.home.username}/share:/run/current-system/sw/share"
        "QS_ICON_THEME=${themeAssets.icons.dark}"
      ];
    };
  };

  programs.dank-material-shell = {
    enable = true;

    systemd.enable = true;

    enableSystemMonitoring = true; # System monitoring widgets (dgop)
    enableVPN = true; # VPN management widget
    enableDynamicTheming = true; # Wallpaper-based theming (matugen)
    enableAudioWavelength = true; # Audio visualizer (cava)
    enableCalendarEvents = true; # Calendar integration (khal)
    enableClipboardPaste = true; # Clipboard paste wtype

    settings = lib.recursiveUpdate dmsSettings {
      customThemeFile = "${pkgs.writeText "yimoka.json" (builtins.toJSON yimokaTheme)}";
      lockScreenInactiveColor = c "base00";
      cursorSettings = {
        inherit (themeAssets.cursor) size;
        theme = themeAssets.cursor.name;
      };
      fontFamily = themeAssets.fonts.sansSerif.name;
      monoFontFamily = themeAssets.fonts.monospace.name;
      barConfigs = map (
        bar: bar // { screenPreferences = config.host.barScreenPreferences; }
      ) dmsSettings.barConfigs;
      animationDuration = scale 250;
      popoutAnimationDuration = scale 150;
      modalAnimationDuration = scale 150;
    };
  };
}
