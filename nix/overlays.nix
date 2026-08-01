[
  (_final: prev: {
    rtk = prev.rtk.overrideAttrs (oldAttrs: {
      env = (oldAttrs.env or { }) // {
        RUSTFLAGS = "-A dead_code";
      };
    });

  })
]
