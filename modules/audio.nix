{ pkgs, inputs, ... }:
let
  unstable = import ./nixpkgs-unstable.nix { inherit inputs pkgs; };
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
        "default.clock.quantum" = 256;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 1024;
      };
    };

    extraConfig.client."99-qbz-bitperfect-audio" = {
      "stream.rules" = [
        {
          matches = [
            { "application.process.binary" = "qbz"; }
            { "application.name" = "PipeWire ALSA [qbz]"; }
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
              "node.name" = "alsa_output.usb-Feixiang_USB_HIFI_Audio-01.pro-output-0";
              "media.class" = "Audio/Sink";
            }
          ];
          actions = {
            update-props = {
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
    unstable.reaper
    unstable.ardour
    unstable.bitwig-studio

    # Guitar amp simulators
    unstable.guitarix
    unstable.tonelib-gfx
    unstable.neural-amp-modeler-lv2

    # Audio plugins (LV2/VST)
    unstable.lsp-plugins
    unstable.kapitonov-plugins-pack
    unstable.reaper-reapack-extension
    unstable.calf
    unstable.zam-plugins
    unstable.dragonfly-reverb
    unstable.chow-tape-model
    unstable.x42-plugins
    unstable.drumgizmo
    unstable.x42-avldrums

    # Routing & monitoring
    unstable.qpwgraph
    unstable.pavucontrol
    unstable.alsa-scarlett-gui
  ];

  environment.sessionVariables = {
    LV2_PATH = "/run/current-system/sw/lib/lv2:$HOME/.lv2";
    VST_PATH = "/run/current-system/sw/lib/vst:$HOME/.vst";
    VST3_PATH = "/run/current-system/sw/lib/vst3:$HOME/.vst3";
    LADSPA_PATH = "/run/current-system/sw/lib/ladspa:$HOME/.ladspa";
  };

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
