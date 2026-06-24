{
  inputs,
  pkgs,
  lib,
  ...
}:

let
  themeAssets = import ../../modules/theme-assets.nix { inherit inputs pkgs; };
  dmsSettings = builtins.fromJSON (builtins.readFile ./dms/settings.json);
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

  imports = [
    inputs.dms.homeModules.dank-material-shell
  ];

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

    settings = dmsSettings // {
      currentThemeName = lib.mkForce "dynamic";
      currentThemeCategory = lib.mkForce "dynamic";
      customThemeFile = lib.mkForce "";
      iconTheme = lib.mkForce themeAssets.icons.dark;
      cursorSettings = dmsSettings.cursorSettings // {
        size = lib.mkForce themeAssets.cursor.size;
        theme = lib.mkForce themeAssets.cursor.name;
      };
      fontFamily = lib.mkForce themeAssets.fonts.sansSerif.name;
      monoFontFamily = lib.mkForce themeAssets.fonts.monospace.name;
    };

    session = builtins.fromJSON (builtins.readFile ./dms/session.json) // {
      wallpaperPath = lib.mkForce "${../../modules/desktop/wallpaper.jpg}";
      wallpaperPathLight = lib.mkForce "${../../modules/desktop/wallpaper.jpg}";
      wallpaperPathDark = lib.mkForce "${../../modules/desktop/wallpaper.jpg}";
    };
  };

  # home.activation.makeDmsMutable = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
  #   # settings.json
  #   target_settings="$HOME/.config/DankMaterialShell/settings.json"
  #   if [ -L "$target_settings" ]; then
  #     store_path=$(readlink -f "$target_settings")
  #     rm -f "$target_settings"
  #     cp "$store_path" "$target_settings"
  #     chmod u+w "$target_settings"
  #   fi

  #   # session.json
  #   target_session="$HOME/.local/state/DankMaterialShell/session.json"
  #   if [ -L "$target_session" ]; then
  #     store_path=$(readlink -f "$target_session")
  #     rm -f "$target_session"
  #     cp "$store_path" "$target_session"
  #     chmod u+w "$target_session"
  #   fi
  # '';
}

# systemd.user.services.dms = {
#   Unit = {
#     After = [ "graphical-session.target" ];
#     PartOf = [ "graphical-session.target" ];
#   };
#
#   Service = {
#     ExecStart = "${
#       lib.getExe inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell
#     } run --session";
#     Restart = "on-failure";
#     RestartSec = 5;
#     Environment = lib.mkForce (
#       lib.concatStringsSep " " [
#         "PATH=${
#           lib.makeBinPath [ inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.quickshell ]
#         }:/run/current-system/sw/bin:${config.home.profileDirectory}/bin"
#         "QT_QPA_PLATFORM=wayland"
#         "QT_WAYLAND_DISABLE_WINDOWDECORATION=1"
#       ]
#     );
#   };
#
#   Install = {
#     WantedBy = [ "graphical-session.target" ];
#   };
# };
