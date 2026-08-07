{ inputs }: [
  (_final: prev: {
    rtk = prev.rtk.overrideAttrs (oldAttrs: {
      env = (oldAttrs.env or { }) // {
        RUSTFLAGS = "-A dead_code";
      };
    });

  })

  (_final: prev: {
    # Workaround for niri-flake expecting libdisplay-info_0_2
    libdisplay-info_0_2 =
      inputs.attic.inputs.nixpkgs.legacyPackages.${prev.stdenv.hostPlatform.system}.libdisplay-info_0_2;
  })

  inputs.niri.overlays.niri
]
