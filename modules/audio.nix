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
        "default.clock.quantum" = 128;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 1024;
      };
    };
  };

  environment.systemPackages = [
    # DAW
    unstable.reaper

    # Guitar amp simulators
    unstable.guitarix
    unstable.tonelib-gfx
    unstable.neural-amp-modeler-lv2

    # Audio plugins (LV2/VST)
    unstable.lsp-plugins
    unstable.calf

    # Routing & monitoring
    unstable.qpwgraph
    unstable.pavucontrol
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
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
  ];
}
