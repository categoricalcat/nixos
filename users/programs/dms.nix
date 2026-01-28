{
  inputs,
  pkgs,
  lib,
  ...
}:
{

  systemd.user.services.swww = {
    Unit = {
      Description = "swww wallpaper daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.swww}/bin/swww-daemon";
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

    # settings = builtins.fromJSON (builtins.readFile ./dms-theme.json);

    enableSystemMonitoring = true; # System monitoring widgets (dgop)
    enableVPN = true; # VPN management widget
    enableDynamicTheming = true; # Wallpaper-based theming (matugen)
    enableAudioWavelength = true; # Audio visualizer (cava)
    enableCalendarEvents = true; # Calendar integration (khal)
    enableClipboardPaste = true; # Clipboard paste wtype
  };

  home.packages = [
    inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.quickshell
    pkgs.qt6.qtwayland
  ];

  home.activation.initDmsSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config/DankMaterialShell"
    if [ ! -f "$HOME/.config/DankMaterialShell/settings.json" ]; then
      cp "${pkgs.writeText "dms-default-settings.json" (builtins.readFile ./dms-theme.json)}" "$HOME/.config/DankMaterialShell/settings.json"
      chmod +w "$HOME/.config/DankMaterialShell/settings.json"
    fi
  '';
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
