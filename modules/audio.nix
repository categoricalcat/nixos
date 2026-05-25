{ pkgs, inputs, ... }:
let
  unstable = import ./nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
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
          48000
          96000
          192000
        ];
        "default.clock.quantum" = 512;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 1024;
      };
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
  ];

  # Plugin search paths so DAWs can find NixOS-installed LV2/VST/VST3/LADSPA
  environment.variables = {
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
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
  ];
}
