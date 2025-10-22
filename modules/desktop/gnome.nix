{
  pkgs,
  lib,
  config,
  ...
}:

{
  config = lib.mkIf (config.desktop.environment == "gnome") {
    services = {
      xserver.enable = false;

      desktopManager = {
        gnome = {
          enable = true;
          extraGSettingsOverrides = ''
            [org.gnome.mutter]
            experimental-features=['scale-monitor-framebuffer', 'xwayland-native-scaling']
          '';
        };
      };

      displayManager = {
        gdm = {
          enable = true;
          wayland = true;
        };
      };

      gnome = {
        core-apps.enable = true;
        core-developer-tools.enable = false;
        games.enable = false;
      };
    };

    environment.gnome.excludePackages = with pkgs; [
      gnome-tour
      gnome-user-docs
    ];

    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    environment.systemPackages = with pkgs; [
      gnomeExtensions.user-themes
      gnomeExtensions.dash-to-dock
      gnomeExtensions.blur-my-shell
      gnomeExtensions.appindicator
      gnomeExtensions.vitals
      gnomeExtensions.gsconnect
      gnomeExtensions.quick-settings-tweaker
      gnomeExtensions.caffeine
      gnomeExtensions.tiling-assistant
      gnomeExtensions.pano
      # gnomeExtensions.just-perfection
    ];
  };
}
