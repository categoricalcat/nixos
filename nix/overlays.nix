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
  })

  inputs.niri.overlays.niri
]
