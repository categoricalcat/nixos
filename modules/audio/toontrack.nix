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

  # FAudio 20.07 win64 DLLs (winetricks LATEST): prevents EZdrummer 3 audio core dumps.
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
      local dll name
      # FAudio prevents audio core dumps; DXVK fixes frozen JUCE D3D11 rendering.
      # Copy instead of symlinking so the prefix remains independent of store GC.
      for dll in \
        "${faudio}/x64/"*.dll \
        "${lib.getBin pkgs.dxvk}/x64/d3d10core.dll" \
        "${lib.getBin pkgs.dxvk}/x64/d3d11.dll" \
        "${lib.getBin pkgs.dxvk}/x64/dxgi.dll"; do
        name="''${dll##*/}"
        install -m0644 "$dll" "$WINEPREFIX/drive_c/windows/system32/$name"
        wine reg add 'HKEY_CURRENT_USER\Software\Wine\DllOverrides' /v "''${name%.dll}" /d native /f > /dev/null
      done
    '';
    # Product Manager uses a short-lived signed URL behind a toontrack.com login,
    # so the archive is supplied by the user on first install rather than fetched by Nix.
    body = ''
      zip="''${1:-}"
      exe="$WINEPREFIX/drive_c/Program Files (x86)/Toontrack/Toontrack Product Manager.exe"

      if [[ -n "$zip" ]]; then
        need "$zip" "No such file: $zip"
        work="$(mktemp -d)"
        trap 'rm -rf "$work"' EXIT
        unzip -q -o "$zip" -d "$work"
        # The zip ships Windows 7/8/10/11 folders (1.0.8..1.1.2); pick 1.1.2 deterministically
        installer="$work/Toontrack_Product_Manager_WIN/Windows 11/Toontrack Product Manager Installer.exe"
        need "$installer" "No installer found in $zip"
        init_prefix
        notify-send "Toontrack" "Installing Toontrack Product Manager from $zip…" || true
        wine "$installer" /s /v"/qn"
        wineserver -w
        rm -rf "$work"
        trap - EXIT
      fi

      if [[ ! -f "$exe" ]]; then
        printf '%s\n' \
          "Toontrack Product Manager is not installed yet." \
          "Download Toontrack_Product_Manager_WIN.zip from toontrack.com, then run:" \
          "  toontrack-pm ~/Downloads/Toontrack_Product_Manager_WIN.zip" >&2
        notify-send "Toontrack" "Run: toontrack-pm ~/Downloads/Toontrack_Product_Manager_WIN.zip" || true
        exit 1
      fi

      init_prefix
      exec wine "$exe"
    '';
  };
in
{
  yi.audio.pluginPrefixes.toontrack = {
    inherit vst3Dir;
    watch = [
      "EZdrummer 3.vst3/Contents/x86_64-win"
      "Superior Drummer 3.vst3/Contents/x86_64-win"
    ];
  };

  home.packages = [ pmLauncher ];

  xdg.desktopEntries.toontrack-pm = {
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
}
