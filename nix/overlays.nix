{ inputs }: [
  (_final: prev: {
    rtk = prev.rtk.overrideAttrs (oldAttrs: {
      env = (oldAttrs.env or { }) // {
        RUSTFLAGS = "-A dead_code";
      };
    });

    vector = prev.vector.overrideAttrs (oldAttrs: {
      doCheck = false;
      env = (oldAttrs.env or { }) // {
        RUSTFLAGS = "--cap-lints warn";
        CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
        CARGO_PROFILE_RELEASE_LTO = "thin";
      };
    });

    high-tide = prev.high-tide.overrideAttrs (oldAttrs: {
      postPatch = (oldAttrs.postPatch or "") + ''
        substituteInPlace src/lib/utils.py \
          --replace-fail "IMG_DIR.mkdir(exist_ok=True)" "IMG_DIR.mkdir(parents=True, exist_ok=True)" \
          --replace-fail "MUSIC_DIR.mkdir(exist_ok=True)" "MUSIC_DIR.mkdir(parents=True, exist_ok=True)"
      '';
    });
  })

  (_final: prev: {
    # Workaround for niri-flake expecting libdisplay-info_0_2
    libdisplay-info_0_2 = prev.callPackage (import
      "${prev.path}/pkgs/by-name/li/libdisplay-info/generic.nix"
      {
        version = "0.2.0";
        hash = "sha256-6xmWBrPHghjok43eIDGeshpUEQTuwWLXNHg7CnBUt3Q=";
      }
    ) { };

    # Workaround for sops-nix referencing buildGo125Module removed from nixpkgs
    buildGo125Module = prev.buildGo126Module;
  })

  inputs.niri.overlays.niri
]
