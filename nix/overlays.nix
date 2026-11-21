[
  (_final: prev: {
    # Timing-sensitive like the e2e tests nixpkgs already skips: under parallel CI
    # load the daemon gives up with "took too long to redact" and the build fails.
    # an_untouched_session_is_left_alone_until_it_is_updated flakes the same way, and
    # a failed listener's teardown double-closes an fd, so Rust's io-safety check
    # aborts the test binary (SIGABRT, "IO Safety violation") before the plain
    # failure is even reported.
    atuin = prev.atuin.overrideAttrs (old: {
      checkFlags = old.checkFlags ++ [
        "--skip=a_huge_message_reads_back"
        "--skip=an_untouched_session_is_left_alone_until_it_is_updated"
      ];
    });

    # High Tide's hardcoded Discord Application ID was deleted upstream.
    # Upstream PR #353 (released in v1.7.0) migrated to a newly registered
    # application ID; nixpkgs still ships 1.5.0. The guard keeps the lock bump
    # to >=1.7.0 from failing the build; drop this entry once nixpkgs has it.
    high-tide = prev.high-tide.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        if grep -q 1379096506065223680 src/lib/discord_rpc.py; then
          substituteInPlace src/lib/discord_rpc.py \
            --replace-fail "1379096506065223680" "1570037786474455050"
        fi
      '';
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
