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

  config = lib.mkIf (config.host.desktopEnvironment == "niri" && config.host.desktopShell == "dms") {

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

    programs.dank-material-shell = {
      enable = true;

      systemd.enable = true;

      enableSystemMonitoring = true; # System monitoring widgets (dgop)
      enableVPN = true; # VPN management widget
      enableDynamicTheming = true; # Wallpaper-based theming (matugen)
      enableAudioWavelength = true; # Audio visualizer (cava)
      enableCalendarEvents = false; # Calendar integration (khal)
      enableClipboardPaste = true; # Clipboard paste wtype

      quickshell.package = pkgs.quickshell;

      settings = builtins.mapAttrs (_n: v: lib.mkForce v) dmsSettings // {
        currentThemeName = lib.mkForce "dynamic";
        lockScreenInactiveColor = lib.mkForce "#${colors.base00}";
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
  };
}
