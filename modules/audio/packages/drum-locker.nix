{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  unzip,
  alsa-lib,
  curl,
  freetype,
  libx11,
  libxext,
  libxcursor,
  libxinerama,
  libxrandr,
  libxscrnsaver,
}:
stdenv.mkDerivation {
  pname = "drum-locker";
  version = "1.0.3";

  # S3 publishes no checksum; trust-on-first-use
  src = fetchurl {
    url = "https://audioassaultdownloads.s3.amazonaws.com/AmpLocker/AmpLocker109/DrumLockerLinux.zip";
    hash = "sha256-YPf3ZCVPP4qgVPdj0t5odSQLK1KhnwzrPuJIHF90tL0=";
  };
  # The zip has no top-level folder
  sourceRoot = ".";

  strictDeps = true;

  nativeBuildInputs = [
    autoPatchelfHook
    unzip
  ];

  buildInputs = [
    alsa-lib
    curl
    freetype
    stdenv.cc.cc.lib
  ];

  # dlopen()ed by JUCE (X11 windowing); runtimeDependencies would skip the plugin .so files
  appendRunpaths = [
    (lib.makeLibraryPath [
      libx11
      libxext
      libxcursor
      libxinerama
      libxrandr
      libxscrnsaver
    ])
  ];

  installPhase = ''
    runHook preInstall

    find "Drum Locker.vst3" DrumLockerData -name '.DS_Store' -delete
    mkdir -p "$out/lib/vst3" "$out/lib/lv2" "$out/share/drum-locker"
    cp -r "Drum Locker.vst3" "$out/lib/vst3/"
    cp -r "Drum Locker.lv2" "$out/lib/lv2/"
    cp -r DrumLockerData "$out/share/drum-locker/"

    runHook postInstall
  '';

  meta = {
    description = "Audio Assault Drum Locker drum sample library player (VST3, LV2)";
    homepage = "https://audioassault.mx/getdrumlocker";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
