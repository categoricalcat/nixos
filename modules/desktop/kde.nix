{
  pkgs,
  lib,
  config,
  ...
}:

{
  config = lib.mkIf (config.desktop.environment == "kde") {
    services = {
      xserver.enable = true;

      desktopManager = {
        plasma6 = {
          enable = true;
        };
      };

      displayManager = {
        sddm = {
          enable = true;
          wayland.enable = false;
        };
      };
    };

    environment.systemPackages = with pkgs; [
      kdePackages.xdg-desktop-portal-kde
    ];

    home-manager.sharedModules = [ ./kde-home.nix ];
  };
}
