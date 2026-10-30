_:
let
  rates = [
    44100
    48000
    88200
    96000
    176400
    192000
  ];

  bitperfect = {
    "resample.disable" = true;
    "channelmix.disable" = true;
  };

  rule = matches: props: {
    inherit matches;
    actions.update-props = props;
  };
in
{
  imports = [ ./plugins.nix ];

  musnix = {
    enable = true;
    rtcqs.enable = true;
    rtirq = {
      enable = true;
      # USB first so the Scarlett's xhci_hcd IRQ thread (95..90) outranks
      # PipeWire/JACK RT threads (88); HDA lands at 90.
      nameList = "usb snd i8042";
      prioHigh = 95;
    };
  };

  # rtirq parses `chrt -p` output with awk '/priority/'; under a pt_BR locale the
  # parse yields an empty priority and the script re-prioritizes every IRQ thread.
  systemd.services.rtirq.environment.LC_ALL = "C";

  # Base PipeWire (alsa, pulse, rtkit) comes from modules/desktop.nix.
  services.pipewire = {
    jack.enable = true;

    extraConfig = {
      pipewire."10-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = 96000;
          "default.clock.allowed-rates" = rates;
          # 384 @ 96k = 4.0 ms; pipewire would round non-power-of-two quanta down.
          "default.clock.quantum" = 384;
          "default.clock.min-quantum" = 384;
          "default.clock.max-quantum" = 384;
          "clock.power-of-two-quantum" = false;
        };
      };

      # Bitperfect stream matching for dedicated Hi-Fi audio player. autoaudiosink never
      # picks pipewiresink (GST_RANK_NONE), so High Tide streams through pipewire-pulse.
      pipewire-pulse."99-high-tide-bitperfect-audio" = {
        "stream.rules" = [
          (rule [ { "application.name" = "~[Hh]igh[- ]?[Tt]ide.*"; } ] bitperfect)
        ];
      };
    };

    wireplumber.extraConfig = {
      # Scarlett 4i4: Pro Audio Profile & preferred default.
      # No priority overrides: WirePlumber's computed USB pro-audio priorities
      # (capture 2600 > playback 1600) keep the graph capture-driven. No api.alsa.headroom:
      # it raises the follower target and multiplies resyncs when the JACK client runs late.
      "10-scarlett-pro-audio" = {
        "device.profile.priority.rules" = [
          (rule [ { "device.name" = "~alsa_card.usb-Focusrite_Scarlett_4i4.*"; } ] {
            "priorities" = [ "pro-audio" ];
          })
        ];
      };

      # Feixiang DAC: Bitperfect output for Hi-Fi audio player; 1500 stays below the
      # Scarlett output (1600) so the Scarlett remains the default sink.
      "99-high-tide-dac-audio" = {
        "monitor.alsa.rules" = [
          (rule
            [
              {
                "node.name" = "~alsa_output.usb-Feixiang_USB_HIFI_Audio-01.*";
                "media.class" = "Audio/Sink";
              }
            ]
            (
              bitperfect
              // {
                "priority.session" = 1500;
                "priority.driver" = 1500;
                "audio.allowed-rates" = rates;
              }
            )
          )
        ];
      };

      # Disable suspend pops on all ALSA hardware
      "99-disable-suspend" = {
        "monitor.alsa.rules" = [
          (rule [
            { "node.name" = "~alsa_input.*"; }
            { "node.name" = "~alsa_output.*"; }
          ] { "session.suspend-timeout-seconds" = 0; })
        ];
      };
    };
  };

  # musnix already grants @audio rtprio 99 and memlock unlimited; nice -11 is
  # PipeWire module-rt's default nice.level.
  security.pam.loginLimits = [
    {
      domain = "@audio";
      item = "nice";
      type = "-";
      value = "-11";
    }
  ];
}
