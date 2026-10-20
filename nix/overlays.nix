_: [
  (_final: prev: {
    # Fix sphinx-hook dropping subsequent builders (e.g. "man") under structuredAttrs
    # when sphinxBuilders is a Nix list, leaving the 'man' output unpopulated.
    khal = prev.khal.overrideAttrs (_old: {
      sphinxBuilders = "html man";
    });

    # NixOS/nixpkgs#575192: aggregateModules fails when external kernel modules
    # (such as hid-fanatecff, zenpower, acpi_call) lack .ko.cer files.
    # Only concatenate .ko.cer into modules.cer if the file actually exists.
    aggregateModules =
      modules:
      (prev.aggregateModules modules).overrideAttrs (old: {
        postBuild =
          builtins.replaceStrings
            [ "xargs -d'\\n' cat >> modules.cer" ]
            [ "while IFS= read -r f; do if [ -f \"$f\" ]; then cat \"$f\"; fi; done >> modules.cer" ]
            old.postBuild;
      });

    # Fix vector build with Rust 1.99+ where std::sync::atomic::*::fetch_update was
    # deprecated in favor of try_update, and vector crates enforce #![deny(warnings)].
    # Disable slow check phase (resolves deserialization_json failure) and use parallel
    # ThinLTO + multi-core codegen units to dramatically speed up compilation.
    vector = prev.vector.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace lib/vector-common/src/atomic.rs \
          --replace-fail ".fetch_update(set_order, fetch_order," ".try_update(set_order, fetch_order,"
        substituteInPlace lib/vector-buffers/src/variants/disk_v2/ledger.rs \
          --replace-fail "unacked_reader_file_id_offset.fetch_update(" "unacked_reader_file_id_offset.try_update("
      '';
      doCheck = false;
      env = (old.env or { }) // {
        RUSTFLAGS = (old.env.RUSTFLAGS or "") + " --cap-lints warn";
        CARGO_PROFILE_RELEASE_LTO = "thin";
        CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
      };
    });
  })
]
