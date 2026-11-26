{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  unzip,
  libx11,
  libxcb,
  libxcb-util,
  libxcb-cursor,
  libxkbcommon,
  glib,
  cairo,
  pango,
  fontconfig,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "mt-power-drum-kit";
  version = "2.1.5.3";

  # Upstream publishes no checksum; trust-on-first-use
  src = fetchurl {
    url = "https://cdn2.resources.manda-audio.com/DOWNLOADS/products/mtpdk2_free/2.1.5/MTPDK-${finalAttrs.version}-VST3-64bit-Linux-FULL.zip";
    hash = "sha256-0D8C2Yl/bchyE5Vx0XWZ9ZxP5U1H+tIXj5837xCyZFY=";
  };
  # The zip has no top-level folder
  sourceRoot = ".";

  strictDeps = true;

  nativeBuildInputs = [
    autoPatchelfHook
    unzip
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    libx11
    libxcb
    libxcb-util
    libxcb-cursor
    libxkbcommon
    glib
    cairo
    pango
    fontconfig
  ];

  installPhase = ''
    runHook preInstall

    # Strip the aarch64 binary so autoPatchelfHook only processes x86_64-linux
    rm -rf MT-PowerDrumKit.vst3/Contents/aarch64-linux
    mkdir -p "$out/lib/vst3"
    cp -r MT-PowerDrumKit.vst3 "$out/lib/vst3/"

    runHook postInstall
  '';

  meta = {
    description = "Manda Audio MT Power Drum Kit 2 acoustic drum sampler (VST3)";
    homepage = "https://www.powerdrumkit.com";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
})
