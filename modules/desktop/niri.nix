{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

{
  config = lib.mkIf (config.desktop.environment == "niri") {

    programs.niri.enable = true;

    services.displayManager = {
      gdm.enable = true;
    };

    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    #packages
    environment.systemPackages = with pkgs; [
      gnome-screenshot
      niri
      xwayland-satellite
      inputs.niri-float-sticky.packages.${pkgs.system}.default
    ];
  };
}
