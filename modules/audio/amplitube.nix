{
  config,
  lib,
  pkgs,
  ...
}:
let
  prefix = ".local/share/wineprefixes/ik-multimedia";
  vst3 = "${config.home.homeDirectory}/${prefix}/drive_c/Program Files/Common Files/VST3";
  wine = pkgs.wineWow64Packages.yabridge;
  wineAsio = pkgs.wineasio.override { wineWow64Packages.stable = wine; };

  productManagerVersion = "1.1.16";
  # IK's CDN publishes no checksum; trust-on-first-use
  productManagerSetup = pkgs.fetchzip {
    name = "ik-product-manager-setup-${productManagerVersion}";
    url = "https://g1.ikmultimedia.com/plugins/ProductManager/ik_product_manager_${productManagerVersion}.zip";
    hash = "sha256-DUxn/nK8XFotJTXnL3iaaiCI2u2Oh6xDttFBSlLjbmk=";
    # The CDN answers 403 without IK's site as referer
    curlOptsList = [
      "--referer"
      "https://www.ikmultimedia.com/"
    ];
  };

  launcher =
    name: body:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.libnotify
        wine
        wineAsio
      ];
      runtimeEnv = {
        WINEARCH = "win64";
        WINEDLLPATH = "${wineAsio}/lib/wine";
        WINEDLLOVERRIDES = "winemenubuilder.exe=d";
      };
      text = ''
        export WINEPREFIX="$HOME/${prefix}"
        ik="$WINEPREFIX/drive_c/Program Files/IK Multimedia"

        need() {
          [[ -f "$1" ]] && return
          printf '%s\n' "$2" >&2
          notify-send "IK Multimedia" "$2" || true
          exit 1
        }

        if [[ ! -f "$WINEPREFIX/system.reg" ]]; then
          mkdir -p "$WINEPREFIX"
          # Wine Mono and Gecko are not bundled; skip their download prompts
          WINEDLLOVERRIDES="$WINEDLLOVERRIDES;mscoree,mshtml=" wineboot --init
          install -m0644 "$WINEDLLPATH/x86_64-windows/wineasio64.dll" "$WINEPREFIX/drive_c/windows/system32/"
          # /s suppresses the result dialog; a bare /nix path would resolve against the current drive
          wine regsvr32 /s "Z:$WINEDLLPATH/x86_64-unix/wineasio64.dll.so"
        fi

        ${body}
      '';
    };

  productManager = launcher "ik-product-manager" ''
    exe="$ik/IK Product Manager/IK Product Manager.exe"
    if [[ ! -f "$exe" ]]; then
      wine "${productManagerSetup}/Install IK Product Manager (v${productManagerVersion}).exe" /S
      wineserver -w
    fi
    need "$exe" "IK Product Manager failed to install."
    exec wine "$exe"
  '';

  amplitube = launcher "amplitube-5" ''
    exe="$ik/AmpliTube 5/AmpliTube 5.exe"
    need "$exe" "Install AmpliTube 5 from IK Product Manager first."
    # xwayland-satellite maps Wine dropdowns as separate windows, so niri's focus changes close them
    exec wine explorer /desktop=AmpliTube,1920x1080 "$(winepath -w "$exe")"
  '';
in
{
  home.packages = [
    pkgs.yabridge
    pkgs.yabridgectl
  ];

  xdg.configFile."yabridgectl/config.toml".source =
    (pkgs.formats.toml { }).generate "yabridgectl.toml"
      {
        plugin_dirs = [ vst3 ];
        yabridge_home = "${pkgs.yabridge}/lib";
        # Verification records the Wine version in this file, which is read-only
        no_verify = true;
      };

  systemd.user = {
    services.yabridge-sync = {
      Unit = {
        Description = "Bridge Windows VST3 plugins from the IK Multimedia prefix";
        ConditionPathIsDirectory = vst3;
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe pkgs.yabridgectl} sync";
      };
      Install.WantedBy = [ "default.target" ];
    };

    paths.yabridge-sync = {
      Unit.Description = "Watch the IK Multimedia prefix for VST3 installs";
      # The bundle folder appears before the installer finishes; its binary lands when the copy completes
      Path.PathChanged = [
        vst3
        "${vst3}/AmpliTube 5.vst3/Contents/x86_64-win"
      ];
      Install.WantedBy = [ "default.target" ];
    };
  };

  xdg.desktopEntries = {
    amplitube-5 = {
      name = "AmpliTube 5";
      comment = "IK Multimedia guitar amp and effects workstation";
      exec = lib.getExe amplitube;
      icon = "audio-card";
      categories = [
        "Audio"
        "AudioVideo"
      ];
    };
    ik-product-manager = {
      name = "IK Product Manager";
      comment = "Install, update, and authorize IK Multimedia products";
      exec = lib.getExe productManager;
      icon = "system-software-install";
      categories = [
        "Audio"
        "AudioVideo"
      ];
    };
  };
}
