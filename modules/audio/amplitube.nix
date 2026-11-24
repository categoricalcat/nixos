{
  config,
  lib,
  pkgs,
  ...
}:
let
  audio = import ./wine-launcher.nix { inherit pkgs; };
  inherit (audio) mkLauncher mkPrefix wine;
  inherit (mkPrefix config.home.homeDirectory "ik-multimedia") prefix vst3Dir;

  wineAsio = (pkgs.wineasio.override { wineWow64Packages.stable = wine; }).overrideAttrs (old: {
    # jackbridge dlopen()s a bare soname, which misses PipeWire JACK without LD_LIBRARY_PATH
    postPatch = (old.postPatch or "") + ''
      substituteInPlace jackbridge.c \
        --replace-fail 'dlopen("libjack.so.0"' 'dlopen("${pkgs.pipewire.jack}/lib/libjack.so.0"'
    '';
  });

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
    mkLauncher {
      inherit name prefix;
      title = "IK Multimedia";
      runtimeInputs = [ wineAsio ];
      runtimeEnv.WINEDLLPATH = "${wineAsio}/lib/wine";
      init = ''
        install -m0644 "$WINEDLLPATH/x86_64-windows/wineasio64.dll" "$WINEPREFIX/drive_c/windows/system32/"
        # /s suppresses the result dialog; a bare /nix path would resolve against the current drive
        wine regsvr32 /s "Z:$WINEDLLPATH/x86_64-unix/wineasio64.dll.so"
      '';
      inherit body;
    };

  productManager = launcher "ik-product-manager" ''
    init_prefix
    exe="$WINEPREFIX/drive_c/Program Files/IK Multimedia/IK Product Manager/IK Product Manager.exe"
    if [[ ! -f "$exe" ]]; then
      wine "${productManagerSetup}/Install IK Product Manager (v${productManagerVersion}).exe" /S
      wineserver -w
    fi
    need "$exe" "IK Product Manager failed to install."
    exec wine "$exe"
  '';

  amplitube = launcher "amplitube-5" ''
    exe="$WINEPREFIX/drive_c/Program Files/IK Multimedia/AmpliTube 5/AmpliTube 5.exe"
    need "$exe" "Install AmpliTube 5 from IK Product Manager first."
    init_prefix
    # xwayland-satellite maps Wine dropdowns as separate windows, so niri's focus changes close them
    exec wine explorer /desktop=AmpliTube,1920x1080 "$(winepath -w "$exe")"
  '';
in
{
  yi.audio.pluginPrefixes.ik-multimedia = {
    inherit vst3Dir;
    watch = [ "AmpliTube 5.vst3/Contents/x86_64-win" ];
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
