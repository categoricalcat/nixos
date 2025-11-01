{
  pkgs,
  lib,
  config,
  ...
}:

{
  config = lib.mkIf (config.desktop.environment == "kde") {
    services = {
      xserver.enable = false;

      desktopManager = {
        plasma6 = {
          enable = true;
        };
      };

      displayManager = {
        sddm = {
          enable = true;
          wayland.enable = true;
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

    environment.systemPackages = with pkgs; [
      kdePackages.xdg-desktop-portal-kde
    ];

    # stylix settings are provided by modules/desktop/stylix.nix
  };
}
