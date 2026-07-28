[
  (_final: prev: {
    rtk = prev.rtk.overrideAttrs (oldAttrs: {
      env = (oldAttrs.env or { }) // {
        RUSTFLAGS = "-A dead_code";
      };
    });

    lact = prev.lact.override {
      libdisplay-info = prev.libdisplay-info_0_2;
    };
  })
]
