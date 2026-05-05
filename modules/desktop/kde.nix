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
        defaultSession = lib.mkIf (config.desktop.greeter == "sddm") "plasma";

        sddm = {
          enable = config.desktop.greeter == "sddm";
          wayland.enable = true;
        };
      };
    };

    environment.systemPackages = with pkgs; [
      kdePackages.xdg-desktop-portal-kde
    ];

    home-manager.sharedModules = [ ./kde-home.nix ];
  };
}
