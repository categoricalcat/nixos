{ lib, pkgs, ... }:
let
  audioPkgs = lib.packagesFromDirectoryRecursive {
    inherit (pkgs) callPackage;
    directory = ./packages;
  };
in
{
  # Writable directories in $HOME for user plugins and NAM models
  systemd.user.tmpfiles.rules = map (dir: "d %h/${dir} 0755 - - - -") [
    ".vst"
    ".vst3"
    ".lv2"
    ".clap"
    ".ladspa"
    "Audio/nam"
    "Audio/ir"
    "Audio/reaper-fxchains"
  ];

  environment.systemPackages = [
    # DAWs & Audio Editors
    pkgs.reaper
    # pkgs.reaper-reapack-extension
    # pkgs.ardour
    # pkgs.bitwig-studio
    pkgs.tenacity

    # Amp & cabinet simulators
    pkgs.guitarix
    pkgs.gxplugins-lv2
    pkgs.tonelib-gfx
    pkgs.tonelib-metal
    pkgs.neural-amp-modeler-lv2
    pkgs.ir-lv2
    pkgs.chow-centaur

    # Tape / saturation
    pkgs.chow-tape-model # the star — real tape
    pkgs.airwindows-lv2 # ToTape + friends
    pkgs.calf # tape sim + saturator
    pkgs.zam-plugins # ZamTube
    pkgs.caps # AmpVTS
    pkgs.tap-plugins # TubeWarmth

    # Effects (LV2/VST/LADSPA)
    pkgs.lsp-plugins
    pkgs.kapitonov-plugins-pack
    pkgs.dragonfly-reverb
    pkgs.x42-plugins
    pkgs.rkrlv2
    pkgs.mod-distortion
    pkgs.swh_lv2
    pkgs.mda_lv2
    pkgs.infamousplugins
    pkgs.fomp
    pkgs.fil-plugins
    pkgs.fverb
    pkgs.wolf-shaper
    pkgs.noise-repellent

    # Modular & FM Synths / Sequencers / Instruments
    # pkgs.cardinal # depends on carla
    pkgs.dexed
    pkgs.stochas
    pkgs.vmpk
    pkgs.fluidsynth
    pkgs.soundfont-fluid
    pkgs.surge-xt
    pkgs.vital
    pkgs.helm
    pkgs.odin2
    pkgs.sfizz
    pkgs.samplv1
    pkgs.synthv1
    pkgs.padthv1
    pkgs.setbfree
    pkgs.x42-gmsynth

    # Drums
    audioPkgs.mt-power-drum-kit
    # audioPkgs.drum-locker
    pkgs.drumgizmo
    pkgs.x42-avldrums
    pkgs.hydrogen
    pkgs.geonkick
    pkgs.drumkv1

    # Plugin hosts (standalone + plugin)
    pkgs.carla
    pkgs.jalv

    # Routing, Monitoring & DSP
    pkgs.qpwgraph
    pkgs.coppwr
    pkgs.easyeffects
    pkgs.pavucontrol
    pkgs.alsa-scarlett-gui
  ];
}
