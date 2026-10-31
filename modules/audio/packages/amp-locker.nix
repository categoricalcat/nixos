{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  unzip,
  copyDesktopItems,
  makeDesktopItem,
  alsa-lib,
  curl,
  freetype,
  libx11,
  libxext,
  libxcursor,
  libxinerama,
  libxrandr,
  libxscrnsaver,
  pipewire,
}:
stdenv.mkDerivation {
  pname = "amp-locker";
  version = "1.6.0";

  # S3 publishes no checksum; trust-on-first-use
  src = fetchurl {
    url = "https://audioassaultdownloads.s3.amazonaws.com/AmpLocker/AmpLocker109/AmpLockerLinux.zip";
    hash = "sha256-xMKDM593Mbw6P8sKDMJMcTdnsOwLgc68CgqUDwBVYAY=";
  };
  # The zip has no top-level folder
  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    unzip
    copyDesktopItems
  ];

  buildInputs = [
    alsa-lib
    curl
    freetype
    stdenv.cc.cc.lib
  ];

  # dlopen()ed by JUCE (X11 windowing, JACK); runtimeDependencies would skip the plugin .so files
  appendRunpaths = [
    (lib.makeLibraryPath [
      libx11
      libxext
      libxcursor
      libxinerama
      libxrandr
      libxscrnsaver
      pipewire.jack
    ])
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "amp-locker";
      exec = "amp-locker";
      desktopName = "Amp Locker";
      comment = "Audio Assault guitar amp simulator";
      categories = [
        "Audio"
        "AudioVideo"
      ];
    })
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "Amp Locker Standalone" $out/bin/amp-locker
    mkdir -p $out/lib/vst3 $out/lib/lv2 $out/share/amp-locker
    cp -r "Amp Locker.vst3" $out/lib/vst3/
    cp -r "Amp Locker.lv2" $out/lib/lv2/
    cp -r AmpLockerData $out/share/amp-locker/

    runHook postInstall
  '';

  meta = {
    description = "Audio Assault Amp Locker guitar amp simulator (standalone, VST3, LV2)";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "amp-locker";
  };
}
