{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  unzip,
  copyDesktopItems,
  makeDesktopItem,
  alsa-lib,
  libGL,
  wayland,
  libx11,
  libxcursor,
  libxi,
  libxkbcommon,
  pipewire,
}:
let
  version = "0.3.0";
  release = "https://github.com/OpenSauce/rustortion/releases/download/v${version}";
in
stdenv.mkDerivation {
  pname = "rustortion";
  inherit version;

  # sha256 is hex so it can be diffed against GitHub's published asset digest
  srcs = [
    (fetchurl {
      url = "${release}/rustortion-standalone-x86_64-unknown-linux-gnu.tar.xz";
      sha256 = "df4292a6b73f7a14db0a0889653e7fafba792dff2a8f44b2a81c0a9683a777fa";
    })
    (fetchurl {
      url = "${release}/Rustortion-linux-x86_64.zip";
      sha256 = "adfe68085aaa1998c30fa4019c277bf28161809cf4501ddd9e1f3af0eea795a8";
    })
  ];
  # The plugin zip has no top-level folder
  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    unzip
    copyDesktopItems
  ];

  buildInputs = [
    alsa-lib
    libx11
    stdenv.cc.cc.lib
  ];

  # dlopen()ed by the GUI and JACK backends; runtimeDependencies would skip the plugin .so files
  appendRunpaths = [
    (lib.makeLibraryPath [
      libGL
      wayland
      libx11
      libxcursor
      libxi
      libxkbcommon
      pipewire.jack
    ])
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "rustortion";
      exec = "rustortion";
      desktopName = "Rustortion";
      comment = "Low latency guitar amp simulator";
      categories = [
        "Audio"
        "AudioVideo"
      ];
    })
  ];

  installPhase = ''
    runHook preInstall

    standalone=rustortion-standalone-x86_64-unknown-linux-gnu
    install -Dm755 $standalone/rustortion -t $out/bin
    mkdir -p $out/share/rustortion $out/lib/vst3 $out/lib/clap
    cp -r $standalone/impulse_responses $standalone/presets $out/share/rustortion/
    cp -r Rustortion.vst3 $out/lib/vst3/
    cp Rustortion.clap $out/lib/clap/

    runHook postInstall
  '';

  meta = {
    description = "Low latency guitar amp simulator (standalone, VST3, CLAP)";
    homepage = "https://github.com/OpenSauce/rustortion";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "rustortion";
  };
}
