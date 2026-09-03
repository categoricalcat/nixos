{ pkgs, config, ... }:
let
  nix-ld-libraries = config.programs.nix-ld.libraries;

  mt-power-drum-kit = pkgs.callPackage ./mt-power-drum-kit.nix { inherit nix-ld-libraries; };
  # drum-locker = pkgs.callPackage ./drum-locker.nix { inherit nix-ld-libraries; };
in
{
  musnix.enable = true;
  musnix.rtirq.enable = true;

  security.rtkit.enable = true;
  services.pulseaudio.enable = false;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    extraConfig.pipewire."10-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 96000;
        "default.clock.allowed-rates" = [
          44100
          48000
          96000
          192000
        ];

        "default.clock.quantum" = 128;
        "default.clock.min-quantum" = 128;
        "default.clock.max-quantum" = 128;
        "clock.force-quantum" = 128;
      };
    };

    extraConfig.client."99-qbz-bitperfect-audio" = {
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

    wireplumber.extraConfig."99-qbz-dac-audio" = {
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

    wireplumber.extraConfig."10-scarlett-pro-audio" = {
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
    };

    wireplumber.extraConfig."99-disable-suspend" = {
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

  environment.systemPackages = [
    # DAW
    pkgs.reaper
    pkgs.reaper-reapack-extension
    # pkgs.ardour
    # pkgs.bitwig-studio

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

    # Drums
    mt-power-drum-kit
    # drum-locker
    pkgs.drumgizmo
    pkgs.x42-avldrums
    pkgs.hydrogen
    pkgs.geonkick
    pkgs.drumkv1

    # Bass / synths / samplers
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

    # Plugin hosts (standalone + plugin)
    pkgs.carla
    pkgs.jalv

    # Routing & monitoring
    pkgs.qpwgraph
    pkgs.pavucontrol
    pkgs.alsa-scarlett-gui
  ];

  environment.sessionVariables = {
    LV2_PATH = "/run/current-system/sw/lib/lv2:$HOME/.lv2";
    VST_PATH = "/run/current-system/sw/lib/vst:$HOME/.vst";
    VST3_PATH = "/run/current-system/sw/lib/vst3:$HOME/.vst3";
    LADSPA_PATH = "/run/current-system/sw/lib/ladspa:$HOME/.ladspa";
    CLAP_PATH = "/run/current-system/sw/lib/clap:$HOME/.clap";
  };

  systemd.user.tmpfiles.rules = [
    "L+ %h/.vst - - - - /run/current-system/sw/lib/vst"
    "L+ %h/.vst3 - - - - /run/current-system/sw/lib/vst3"
    "L+ %h/.lv2 - - - - /run/current-system/sw/lib/lv2"
    "L+ %h/.clap - - - - /run/current-system/sw/lib/clap"
    "L+ %h/.ladspa - - - - /run/current-system/sw/lib/ladspa"
  ];

  security.pam.loginLimits = [
    {
      domain = "@audio";
      item = "rtprio";
      type = "-";
      value = "95";
    }
    {
      domain = "@audio";
      item = "nice";
      type = "-";
      value = "-11";
    }
    {
      domain = "@audio";
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
  ];
}
