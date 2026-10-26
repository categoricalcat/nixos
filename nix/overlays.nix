_: [
  (_final: prev: {
    fluxer = prev.callPackage ../packages/fluxer { };

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
