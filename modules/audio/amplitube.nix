{ lib, pkgs, ... }:
let
  prefix = ".local/share/wineprefixes/ik-multimedia";
  wine = pkgs.wineWow64Packages.yabridge;
  wineAsio = pkgs.wineasio.override { wineWow64Packages.stable = wine; };
  tools = [
    wine
    wineAsio
    pkgs.winetricks
    pkgs.yabridgectl
  ];

  amplitube = pkgs.writeShellApplication {
    name = "amplitube-5";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.libnotify
    ]
    ++ tools;
    text = ''
      export WINEARCH=win64
      export WINEDLLOVERRIDES="winemenubuilder.exe=d"
      export WINEDLLPATH="${wineAsio}/lib/wine"
      export WINEPREFIX="$HOME/${prefix}"

      manager="$WINEPREFIX/drive_c/Program Files/IK Multimedia/IK Product Manager/IK Product Manager.exe"
      standalone="$WINEPREFIX/drive_c/Program Files/IK Multimedia/AmpliTube 5/AmpliTube 5.exe"
      vst3="$WINEPREFIX/drive_c/Program Files/Common Files/VST3"
      wineasio_marker="$WINEPREFIX/.nix-wineasio"

      usage() {
        cat >&2 <<'EOF'
      Usage:
        amplitube-5 install INSTALLER.exe
        amplitube-5 manager
        amplitube-5 standalone
        amplitube-5 sync
        amplitube-5 winecfg
        amplitube-5 winetricks VERB...
      EOF
      }

      die() {
        printf 'amplitube-5: %s\n' "$*" >&2
        [[ -t 2 ]] || notify-send "AmpliTube 5" "$*" || true
        exit 1
      }

      require_file() {
        [[ -f "$1" ]] || die "$2"
      }

      init_prefix() {
        if [[ ! -f "$WINEPREFIX/system.reg" ]]; then
          mkdir -p "$WINEPREFIX"
          # Wine Mono and Gecko are not bundled; skip their download prompts
          WINEDLLOVERRIDES="$WINEDLLOVERRIDES;mscoree,mshtml=" wineboot --init
        fi
      }

      ensure_wineasio() {
        local registered=""
        if [[ -f "$wineasio_marker" ]]; then
          registered="$(<"$wineasio_marker")"
        fi
        if [[ "$registered" == "${wineAsio}" ]]; then
          return
        fi

        install -Dm0644 "$WINEDLLPATH/x86_64-windows/wineasio64.dll" "$WINEPREFIX/drive_c/windows/system32/wineasio64.dll"
        # A bare /nix path would resolve against the current Wine drive
        wine regsvr32 "Z:$WINEDLLPATH/x86_64-unix/wineasio64.dll.so"
        printf '%s\n' "${wineAsio}" >"$wineasio_marker"
      }

      case "''${1:-}" in
        install) [[ $# -eq 2 ]] ;;
        winetricks) [[ $# -ge 2 ]] ;;
        manager | standalone | sync | winecfg) [[ $# -eq 1 ]] ;;
        *) false ;;
      esac || {
        usage
        exit 2
      }

      subcommand="$1"
      shift
      case "$subcommand" in
        install)
          require_file "$1" "installer not found: $1"
          installer="$(readlink -f -- "$1")"
          init_prefix
          ensure_wineasio
          exec wine "$installer"
          ;;
        manager)
          require_file "$manager" "IK Product Manager is not installed; run: amplitube-5 install INSTALLER.exe"
          exec wine "$manager"
          ;;
        standalone)
          require_file "$standalone" "AmpliTube 5 is not installed; install it from IK Product Manager"
          ensure_wineasio
          # xwayland-satellite maps Wine dropdowns as separate windows, so niri's focus changes close them
          exec wine explorer /desktop=AmpliTube,1920x1080 "$(winepath -w "$standalone")"
          ;;
        sync)
          [[ -e "$vst3/AmpliTube 5.vst3" ]] \
            || die "AmpliTube VST3 is not installed in the default location"
          yabridgectl add "$vst3"
          exec yabridgectl sync
          ;;
        winecfg)
          init_prefix
          exec winecfg
          ;;
        winetricks)
          init_prefix
          exec winetricks "$@"
          ;;
      esac
    '';
  };
in
{
  home.packages = [
    amplitube
    pkgs.yabridge
  ]
  ++ tools;

  systemd.user.tmpfiles.rules = [ "d %h/${prefix} 0755 - - - -" ];

  xdg.desktopEntries = {
    amplitube-5 = {
      name = "AmpliTube 5";
      comment = "IK Multimedia guitar amp and effects workstation";
      exec = "${lib.getExe amplitube} standalone";
      icon = "audio-card";
      categories = [
        "Audio"
        "AudioVideo"
      ];
    };
    ik-product-manager = {
      name = "IK Product Manager";
      comment = "Install, update, and authorize IK Multimedia products";
      exec = "${lib.getExe amplitube} manager";
      icon = "system-software-install";
      categories = [
        "Audio"
        "AudioVideo"
      ];
    };
  };
}
