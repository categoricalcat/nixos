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

    # 0.9.20 aborts the host when Reaper sizes the FX window below the resampling
    # frame chrome. Those sizes are size_t, so `width - 50` underflows and
    # Widget::resize trips `assert(width < 32000 && height < 32000)`.
    # Upstream dd9fd17 (develop, 2025-03-05), still unreleased:
    # http://git.drumgizmo.org/drumgizmo.git/commit/?id=dd9fd17e59155ca05f93c9ec1d48430041f648bd
    # Inlined because a flake git source omits untracked patch files.
    # Drop once pkgs.drumgizmo is past 0.9.20 and contains that commit.
    drumgizmo = prev.drumgizmo.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        (prev.writeText "drumgizmo-reaper-resize.patch" ''
          --- a/plugingui/resamplingframecontent.cc
          +++ b/plugingui/resamplingframecontent.cc
          @@ -30,6 +30,8 @@
           
           #include <translation.h>
           
          +#include <algorithm>
          +
           namespace GUI
           {
           
          @@ -70,9 +72,9 @@
           void ResamplingframeContent::resize(std::size_t width, std::size_t height)
           {
           ''\tWidget::resize(width, height);
          -''\ttext_field.resize(width - 50, height);
          -''\tquality_knob.move(width - 36, 20);
          -''\tquality_label.move(width - 40, 0);
          +''\ttext_field.resize(std::max(width, std::size_t{51}) - 50, height);
          +''\tquality_knob.move(std::max(width, std::size_t{37}) - 36, 20);
          +''\tquality_label.move(std::max(width, std::size_t{41}) - 40, 0);
           }
           
           void ResamplingframeContent::updateContent()
        '')
      ];
    });
  })
]
