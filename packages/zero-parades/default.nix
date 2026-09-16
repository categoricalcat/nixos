{
  lib,
  stdenv,
  makeWrapper,
  fetchurl,
  python3,
  libvorbis,
  libogg,
}:

let
  fsb5 = python3.pkgs.buildPythonPackage rec {
    pname = "fsb5";
    version = "1.0";
    pyproject = true;
    build-system = [ python3.pkgs.setuptools ];
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/source/f/fsb5/fsb5-${version}.tar.gz";
      hash = "sha256-MS0otYDpxKADLKrIC8w1RnIhYyf0MNBjw760pPP+Yh0=";
    };
    doCheck = false;
  };

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
      sha256 = "5daf0c8a979e166f8189038d73c57fb5aa16ea1097da8f4cbdd7180468a0c337";
    };
    dontCheckRuntimeDeps = true;
    propagatedBuildInputs = with python3.pkgs; [
      lz4
      brotli
      fsspec
      attrs
      pillow
      tpk_ar
    ];
    doCheck = false;
  };

  pythonEnv = python3.withPackages (_ps: [
    fsb5
    tpk_ar
    unitypy
  ]);

  libPath = lib.makeLibraryPath [
    libvorbis
    libogg
  ];
in
stdenv.mkDerivation {
  pname = "zero-parades";
  version = "0.1.0";

  src = ./src;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin $out/share/zero-parades
    cp -r * $out/share/zero-parades/

    # 1. zero-parades-extract
    makeWrapper ${pythonEnv}/bin/python $out/bin/zero-parades-extract \
      --set LD_LIBRARY_PATH "${libPath}" \
      --add-flags "$out/share/zero-parades/extract_dialogue.py"

    # 2. zero-parades-play
    makeWrapper ${pythonEnv}/bin/python $out/bin/zero-parades-play \
      --set LD_LIBRARY_PATH "${libPath}" \
      --add-flags "$out/share/zero-parades/player_server.py"

    # 3. zero-parades (dispatcher)
    cat << 'EOF' > $out/bin/zero-parades
    #!/usr/bin/env bash
    set -euo pipefail
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
    EOF

    substituteInPlace $out/bin/zero-parades \
      --subst-var out

    chmod +x $out/bin/zero-parades
  '';

  meta = with lib; {
    description = "Dialogue extractor and on-demand voiceover web player for Zero Parades: For Dead Spies";
    platforms = platforms.linux;
  };
}
