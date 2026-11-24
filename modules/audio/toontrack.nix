{
  config,
  lib,
  pkgs,
  ...
}:
let
  audio = import ./wine-launcher.nix { inherit pkgs; };
  inherit (audio) mkLauncher mkPrefix;
  inherit (mkPrefix config.home.homeDirectory "toontrack") prefix vst3Dir;

  # FAudio 20.07 win64 DLLs (winetricks LATEST): the proven EZD3 core-dump fix.
  # fetchzip hashes the unpacked tree (recursiveHash), not the .tar.xz.
  faudio = pkgs.fetchzip {
    name = "faudio-20.07";
    url = "https://github.com/Kron4ek/FAudio-Builds/releases/download/20.07/faudio-20.07.tar.xz";
    hash = "sha256-h3NlTl3VezlK4+BdcDaP7B08mUIcQw3y7B+ZDct/Maw=";
  };

  pmLauncher = mkLauncher {
    name = "toontrack-pm";
    title = "Toontrack";
    inherit prefix;
    runtimeInputs = [ pkgs.unzip ];
    init = ''
      # Copy the FAudio DLLs (winetricks symlinks them) so the prefix outlives the nix store
      install -m0644 "${faudio}/x64/"*.dll "$WINEPREFIX/drive_c/windows/system32/"
      # Register the native overrides the way winetricks' faudio script does
      for dll in "${faudio}/x64/"*.dll; do
        wine reg add 'HKEY_CURRENT_USER\Software\Wine\DllOverrides' /v "$(basename "$dll" .dll)" /d native /f > /dev/null
      done
    '';
    # The Product Manager's download is a signed URL behind a toontrack.com
    # login, so the zip is supplied by the user, not fetched by Nix.
    body = ''
      zip="''${1:-}"
      exe="$WINEPREFIX/drive_c/Program Files (x86)/Toontrack/Toontrack Product Manager.exe"

      if [[ -n "$zip" ]]; then
        need "$zip" "No such file: $zip"
        work=$(mktemp -d)
        trap 'rm -rf "$work"' EXIT
        unzip -q -o "$zip" -d "$work"
        # The zip ships Windows 7/8/10/11 folders (versions 1.0.8..1.1.2); pick 1.1.2 deterministically
        installer="$work/Toontrack_Product_Manager_WIN/Windows 11/Toontrack Product Manager Installer.exe"
        need "$installer" "No installer found in $zip"
        init_prefix
        notify-send "Toontrack" "Installing the Product Manager from $zip…" || true
        wine "$installer" /s /v"/qn"
        wineserver -w
      fi

      if [[ ! -f "$exe" ]]; then
        printf '%s\n' \
          "The Toontrack Product Manager is not installed yet." \
          "Download Toontrack_Product_Manager_WIN.zip from toontrack.com (account required), then run:" \
          "  toontrack-pm ~/Downloads/Toontrack_Product_Manager_WIN.zip" >&2
        notify-send "Toontrack" "Run toontrack-pm with the Product Manager zip." || true
        exit 1
      fi

      init_prefix
      exec wine "$exe"
    '';
  };

  # yabridge's X11 plugin embedding needs an X11 REAPER under Wayland; the prefix
  # is resolved per plugin by yabridge's dosdevices walk, so no WINEPREFIX here
  reaperToontrack = pkgs.writeShellApplication {
    name = "reaper-toontrack";
    # The yabridge chainloader resolves yabridge-host.exe through the process
    # PATH; putting it in the wrapper keeps bridging working regardless of session env
    runtimeInputs = [
      pkgs.reaper
      pkgs.yabridge
    ];
    runtimeEnv = {
      GDK_BACKEND = "x11";
      # Classic file locking; the Toontrack sample libraries need it (community recipe)
      WINEFSYNC = "0";
      WINEESYNC = "0";
    };
    text = "exec reaper";
  };
in
{
  yi.audio.pluginPrefixes.toontrack = {
    inherit vst3Dir;
    # The installer writes the bundle folder before the binary lands, so the
    # directory holding the plugin is watched alongside its parent
    watch = [
      "EZDrummer 3.vst3/Contents/x86_64-win"
      "Superior Drummer 3.vst3/Contents/x86_64-win"
    ];
  };

  home.packages = [
    pmLauncher
    reaperToontrack
  ];

  xdg.desktopEntries = {
    toontrack-pm = {
      name = "Toontrack Product Manager";
      comment = "Install, update, and authorize Toontrack products";
      # %f lets a file manager hand over the Product Manager zip
      exec = "${lib.getExe pmLauncher} %f";
      icon = "system-software-install";
      categories = [
        "Audio"
        "AudioVideo"
      ];
    };
    reaper-toontrack = {
      name = "REAPER (Toontrack)";
      comment = "REAPER on X11, for the Wine-bridged Toontrack plugins";
      exec = lib.getExe reaperToontrack;
      icon = "audio-midi";
      categories = [
        "Audio"
        "AudioVideo"
        "Midi"
      ];
    };
  };
}
