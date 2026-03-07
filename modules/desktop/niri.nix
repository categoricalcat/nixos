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
      inputs.niri-float-sticky.packages.${pkgs.stdenv.hostPlatform.system}.default
      # inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.quickshell
    ];

    programs.niri.enable = true;

    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      extraConfig.pipewire."10-rates" = {
        "context.properties" = {
          "default.clock.rate" = 192000;
          "default.clock.allowed-rates" = [
            48000
            96000
            192000
          ];
        };
      };
    };

    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-gnome
      ];
      config = {
        common = {
          default = [ "gtk" ];
        };
      };
    };
  };
}
