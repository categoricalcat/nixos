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

    # Fix reaper segfault on startup (NixOS/patchelf#446, NixOS/patchelf#447):
    # patchelf corrupts non-PIE (ET_EXEC) ELF binaries when inserting/expanding RPATH
    # by creating an overlapping PT_LOAD segment where .dynamic falls within a page
    # mapped with read-execute (R-E) permissions instead of read-write (RW-).
    # The dynamic linker crashes with SEGV_ACCERR when dl_main writes to DT_DEBUG.
    # We prevent autoPatchelf from modifying the main reaper binary and reaper_host_x86_64,
    # patch their interpreters directly, and supply runtime libraries via LD_LIBRARY_PATH in the wrapper.
    #
    # We also use pipewire.jack instead of libjack2 so Reaper connects natively
    # to PipeWire's JACK emulation rather than hanging on a nonexistent jackd,
    # and force LC_NUMERIC=C so decimal positions in RPP projects are not truncated under pt_BR.
    reaper =
      (prev.reaper.override {
        jackLibrary = prev.pipewire.jack;
      }).overrideAttrs
        (
          old:
          prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
            dontAutoPatchelf = true;
            installPhase =
              builtins.replaceStrings
                [
                  "--prefix PATH :"
                  "--prefix LD_LIBRARY_PATH : \""
                ]
                [
                  "--set LC_NUMERIC C \\\n          --prefix PATH :"
                  "--prefix LD_LIBRARY_PATH : \"${
                    prev.lib.makeLibraryPath [
                      prev.alsa-lib
                      prev.gtk3
                      prev.pipewire.jack
                      prev.libpulseaudio
                    ]
                  }:"
                ]
                old.installPhase;
            postFixup = (old.postFixup or "") + ''
              autoPatchelf -- "$out/opt/REAPER/Plugins"/*.so "$out/opt/REAPER/Plugins/FX" "$out/opt/REAPER/libSwell.so"
              patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$out/opt/REAPER/.reaper-wrapped"
              patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$out/opt/REAPER/Plugins/reaper_host_x86_64"
            '';
          }
        );
  })
]
