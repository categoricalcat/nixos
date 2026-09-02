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
  dmsSettings = builtins.fromJSON (builtins.readFile ./dms/settings.json);
in
{
  imports = [
  ];

  config =
    lib.mkIf
      (
        lib.elem config.host.desktopEnvironment [
          "niri"
          "mango"
        ]
        && config.host.desktopShell == "dms"
      )
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

        stylix.targets.dank-material-shell.image.enable = false;

        home.sessionVariables = {
          QS_ICON_THEME = themeAssets.icons.dark;
        };

        systemd.user.services.dms = {
          Service = {
            Environment = [
              "XDG_DATA_DIRS=/etc/profiles/per-user/${config.home.username}/share:/run/current-system/sw/share"
              "QS_ICON_THEME=${themeAssets.icons.dark}"
            ];
          };
        };

        home.activation.makeDmsSessionMutable = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          target="$HOME/.local/state/DankMaterialShell/session.json"
          if [ -L "$target" ]; then
            store_path=$(readlink -f "$target")
            rm -f "$target"
            cp "$store_path" "$target"
            chmod u+w "$target"
          fi
        '';

        programs.dank-material-shell = {
          enable = true;

          systemd.enable = true;

          enableSystemMonitoring = true; # System monitoring widgets (dgop)
          enableVPN = true; # VPN management widget
          enableDynamicTheming = true; # Wallpaper-based theming (matugen)
          enableAudioWavelength = true; # Audio visualizer (cava)
          enableCalendarEvents = true; # Calendar integration (khal)
          enableClipboardPaste = true; # Clipboard paste wtype

          quickshell.package = pkgs.quickshell;

          settings = builtins.mapAttrs (_n: v: lib.mkForce v) dmsSettings // {
            currentThemeName = lib.mkForce "custom";
            lockScreenInactiveColor = lib.mkForce "#${colors.base00}";
            currentThemeCategory = lib.mkForce "custom";
            customThemeFile = lib.mkForce "${config.home.homeDirectory}/.config/DankMaterialShell/themes/yimoka.json";
            iconThemeDark = lib.mkForce "System Default";
            iconThemeLight = lib.mkForce "System Default";
            cursorSettings = dmsSettings.cursorSettings // {
              size = lib.mkForce themeAssets.cursor.size;
              theme = lib.mkForce themeAssets.cursor.name;
            };
            fontFamily = lib.mkForce themeAssets.fonts.sansSerif.name;
            monoFontFamily = lib.mkForce themeAssets.fonts.monospace.name;
            barConfigs = lib.mkForce (
              map (bar: bar // { screenPreferences = config.host.barScreenPreferences; }) dmsSettings.barConfigs
            );
          };
        };

        xdg.configFile."DankMaterialShell/themes/yimoka.json".source = ./dms/themes/yimoka.json;
      };
}
