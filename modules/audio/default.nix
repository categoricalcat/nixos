{ pkgs, config, ... }:
let
  nix-ld-libraries = config.programs.nix-ld.libraries;

  mt-power-drum-kit = pkgs.callPackage ./mt-power-drum-kit.nix { inherit nix-ld-libraries; };
  # drum-locker = pkgs.callPackage ./drum-locker.nix { inherit nix-ld-libraries; };
in
{
  musnix = {
    enable = true;
    rtcqs.enable = true;
    rtirq = {
      enable = true;
      highList = "snd_usb_audio snd_hda_intel";
    };
  };

  security.rtkit.enable = true;
  services.pulseaudio.enable = false;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    extraConfig = {
      pipewire."10-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.allowed-rates" = [
            44100
            48000
            88200
            96000
            176400
            192000
          ];
          "default.clock.quantum" = 128;
          "default.clock.min-quantum" = 32;
          "default.clock.max-quantum" = 128;
        };
        "stream.properties" = {
          "resample.quality" = 7;
        };
      };

      # Bitperfect stream matching for dedicated Hi-Fi audio player
      client."99-qbz-bitperfect-audio" = {
        "stream.rules" = [
          {
            matches = [
              { "application.process.binary" = "~.*qbz.*"; }
              { "application.name" = "~.*[Qq]bz.*"; }
            ];
            actions = {
              update-props = {
                "resample.disable" = true;
                "channelmix.disable" = true;
              };
            };
          }
        ];
      };
    };

    wireplumber.extraConfig = {
      # Scarlett 4i4: Pro Audio Profile & ALSA low period buffer
      "10-scarlett-pro-audio" = {
        "device.profile.priority.rules" = [
          {
            matches = [
              {
                "device.name" = "~alsa_card.usb-Focusrite_Scarlett_4i4.*";
              }
            ];
            actions = {
              update-props = {
                "priorities" = [ "pro-audio" ];
              };
            };
          }
        ];
        "monitor.alsa.rules" = [
          {
            matches = [
              {
                "node.name" = "~alsa_input.usb-Focusrite_Scarlett_4i4.*";
              }
            ];
            actions = {
              update-props = {
                "api.alsa.period-size" = 128;
                "api.alsa.headroom" = 64;
              };
            };
          }
        ];
      };

      # Feixiang DAC: Highest priority default system sink with dynamic sample rates & bitperfect
      "99-qbz-dac-audio" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              {
                "node.name" = "~alsa_output.usb-Feixiang_USB_HIFI_Audio-01.*";
                "media.class" = "Audio/Sink";
              }
            ];
            actions = {
              update-props = {
                "priority.session" = 1500;
                "priority.driver" = 1500;
                "audio.allowed-rates" = [
                  44100
                  48000
                  88200
                  96000
                  176400
                  192000
                ];
                "resample.disable" = true;
                "channelmix.disable" = true;
              };
            };
          }
        ];
      };

      # Bluetooth: High-fidelity codecs with adaptive bitrate
      "10-bluez-quality" = {
        "monitor.bluez.rules" = [
          {
            matches = [
              {
                "device.name" = "~bluez_card.*";
              }
            ];
            actions = {
              update-props = {
                "bluez5.roles" = [
                  "a2dp_sink"
                  "a2dp_source"
                  "bap_sink"
                  "bap_source"
                  "hsp_hs"
                  "hsp_ag"
                  "hfp_hf"
                  "hfp_ag"
                ];
                "bluez5.codecs" = [
                  "ldac"
                  "aptx_hd"
                  "aptx"
                  "aac"
                  "sbc_xq"
                  "sbc"
                ];
                "bluez5.enable-sbc-xq" = true;
                "bluez5.a2dp.ldac.quality" = "auto";
              };
            };
          }
        ];
      };

      # Disable suspend pops on all ALSA hardware
      "99-disable-suspend" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              { "node.name" = "~alsa_input.*"; }
              { "node.name" = "~alsa_output.*"; }
            ];
            actions = {
              update-props = {
                "session.suspend-timeout-seconds" = 0;
              };
            };
          }
        ];
      };
    };
  };

  # VST & Plugin Search Paths including Wine/yabridge
  environment.sessionVariables = {
    WINEDLLOVERRIDES = "winemp3.acm=d";
    VST3_PATH = "$HOME/.vst3:/run/current-system/sw/lib/vst3:$HOME/.nix-profile/lib/vst3:$HOME/.wine/drive_c/Program Files/Common Files/VST3";
  };

  # Writable directories in $HOME for user plugins and NAM models
  systemd.user.tmpfiles.rules = [
    "d %h/.vst 0755 - - - -"
    "d %h/.vst3 0755 - - - -"
    "d %h/.lv2 0755 - - - -"
    "d %h/.clap 0755 - - - -"
    "d %h/.ladspa 0755 - - - -"
    "d %h/Audio/nam 0755 - - - -"
    "d %h/Audio/ir 0755 - - - -"
    "d %h/Audio/reaper-fxchains 0755 - - - -"
  ];

  environment.systemPackages = [
    # DAWs & Audio Editors
    pkgs.reaper
    pkgs.reaper-reapack-extension
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
    mt-power-drum-kit
    # drum-locker
    pkgs.drumgizmo
    pkgs.x42-avldrums
    pkgs.hydrogen
    pkgs.geonkick
    pkgs.drumkv1

    # Plugin hosts (standalone + plugin)
    # pkgs.carla
    pkgs.jalv

    # Routing, Monitoring & DSP
    pkgs.qpwgraph
    pkgs.coppwr
    pkgs.easyeffects
    pkgs.pavucontrol
    pkgs.alsa-scarlett-gui
  ];
}
