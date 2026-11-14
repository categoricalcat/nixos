{
  lib,
  stdenv,
  makeWrapper,
  writeShellApplication,
  fetchurl,
  python3,
  libvorbis,
  libogg,
}:

let
  fsb5 = python3.pkgs.buildPythonPackage (finalAttrs: {
    pname = "fsb5";
    version = "1.0";
    pyproject = true;
    build-system = [ python3.pkgs.setuptools ];
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/source/f/fsb5/fsb5-${finalAttrs.version}.tar.gz";
      hash = "sha256-MS0otYDpxKADLKrIC8w1RnIhYyf0MNBjw760pPP+Yh0=";
    };
    postPatch = ''
      substituteInPlace fsb5/vorbis.py \
        --replace-fail "load_lib('vorbis')" "ctypes.CDLL('${libvorbis}/lib/libvorbis.so')" \
        --replace-fail "load_lib('vorbisenc', 'vorbis')" "ctypes.CDLL('${libvorbis}/lib/libvorbisenc.so')" \
        --replace-fail "load_lib('ogg')" "ctypes.CDLL('${libogg}/lib/libogg.so')"
    '';
    doCheck = false;
  });

  tpk_ar = python3.pkgs.buildPythonPackage {
    pname = "tpk_ar";
    version = "0.2.4";
    pyproject = true;
    build-system = [ python3.pkgs.setuptools ];
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/fa/02/654a73cbd323970b5c1551881968dbadec1d697984fff5fdd33b66764dfc/tpk_ar-0.2.4.tar.gz";
      hash = "sha256-1kiX5aC83dWOin1N2SLzctqYSg+YvDtGDshpqrkG7ng=";
    };
    doCheck = false;
  };

  unitypy = python3.pkgs.buildPythonPackage {
    pname = "unitypy";
    version = "1.25.3";
    format = "wheel";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/41/b0/5fb5fa6de99e5264339de770a4b9d5c870ac363fd49af2d208e8ad8b858b/unitypy-1.25.3-cp314-cp314-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256-Xa8MipeeFm+BiQONc8V/taoW6hCX2o9MvdcYBGigwzc=";
    };
    dontCheckRuntimeDeps = true;
    dependencies = [
      python3.pkgs.lz4
      python3.pkgs.brotli
      python3.pkgs.fsspec
      python3.pkgs.attrs
      python3.pkgs.pillow
      tpk_ar
    ];
    doCheck = false;
  };

  pythonEnv = python3.withPackages (_ps: [
    fsb5
    tpk_ar
    unitypy
  ]);
in
stdenv.mkDerivation {
  pname = "zero-parades";
  version = "0.1.0";

  src = ./src;

  strictDeps = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/zero-parades
    cp -r * $out/share/zero-parades/

    # 1. zero-parades-extract
    makeWrapper ${lib.getExe pythonEnv} $out/bin/zero-parades-extract \
      --add-flags "$out/share/zero-parades/extract_dialogue.py"

    # 2. zero-parades-play
    makeWrapper ${lib.getExe pythonEnv} $out/bin/zero-parades-play \
      --add-flags "$out/share/zero-parades/player_server.py"

    # 3. zero-parades (dispatcher)
    substitute ${
      lib.getExe (writeShellApplication {
        name = "zero-parades";
        text = ''
          cmd="''${1:-}"
          if [ "$cmd" = "extract" ]; then
            shift
            exec "@out@/bin/zero-parades-extract" "$@"
          elif [ "$cmd" = "play" ] || [ "$cmd" = "player" ]; then
            shift
            exec "@out@/bin/zero-parades-play" "$@"
          else
            echo "Zero Parades Toolset"
            echo "Usage:"
            echo "  zero-parades extract [options]   Extract dialogue lines to CSV/JSON"
            echo "  zero-parades play [options]      Launch interactive voiceover web player"
            echo ""
            echo "Commands:"
            echo "  extract    Run dialogue extractor"
            echo "  play       Start player server and open browser"
            echo ""
            echo "Run 'zero-parades <command> --help' for command-specific options."
            exit 1
          fi
        '';
      })
    } $out/bin/zero-parades --subst-var out
    chmod +x $out/bin/zero-parades

    runHook postInstall
  '';

  meta = {
    description = "Dialogue extractor and on-demand voiceover web player for Zero Parades: For Dead Spies";
    platforms = lib.platforms.linux;
    mainProgram = "zero-parades";
  };
}
