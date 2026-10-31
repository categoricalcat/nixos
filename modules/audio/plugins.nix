{ lib, pkgs, ... }:
let
  audioPkgs = lib.packagesFromDirectoryRecursive {
    inherit (pkgs) callPackage;
    directory = ./packages;
  };
in
{
  home-manager.users.yi = {
    imports = [ ./home.nix ];

    # Amp Locker's default data folder; recursive keeps the folders writable
    home.file."Audio Assault/PluginData/Audio Assault/AmpLockerData" = {
      source = "${audioPkgs.amp-locker}/share/amp-locker/AmpLockerData";
      recursive = true;
    };
  };

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
    audioPkgs.amp-locker
    audioPkgs.rustortion

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
    pkgs.cardinal
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

    # MIDI compose / sequence
    pkgs.lmms
    pkgs.giada
    pkgs.seq66
    pkgs.qmidiarp
    pkgs.helio-workstation
    pkgs.midivisualizer

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
