{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

{
  config = lib.mkIf (config.desktop.environment == "niri") {
    environment.systemPackages = with pkgs; [
      gnome-screenshot
      swww
      xwayland-satellite
      tuigreet
      inputs.niri-float-sticky.packages.${pkgs.stdenv.hostPlatform.system}.default
      # inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.quickshell
    ];

    programs.niri.enable = true;

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          # Customized tuigreet command
          command = ''
            ${pkgs.tuigreet}/bin/tuigreet \
              --time \
              --asterisks \
              --user-menu \
              --greeting "turmoil accompanies every great change" \
              --theme "border=magenta;text=magenta;prompt=magenta;time=magenta;action=magenta;button=magenta;container=black;input=white" \
              --cmd "niri --session" \
              --remember \
              --remember-session
          '';
          user = "greeter";
        };
      };
    };

    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
