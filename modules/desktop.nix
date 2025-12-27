{ lib, ... }:

{
  options = {
    desktop.environment = lib.mkOption {
      type = lib.types.enum [
        "gnome"
        "hyprland"
        "niri"
        "kde"
        "cosmic"
      ];
      default = "gnome";
      description = "Desktop environment to use";
    };
  };

  imports = [
    ./desktop/gnome.nix
    ./desktop/hyprland.nix
    ./desktop/niri.nix
    ./desktop/kde.nix
    ./desktop/cosmic.nix
    ./desktop/stylix.nix
    ./desktop/dms.nix
    ./desktop/apps.nix
  ];

  config = {
    programs = {
      xwayland.enable = true;
    };

    console.keyMap = "br-abnt2";

    services.libinput.enable = true;
    services.gnome.gnome-keyring.enable = true;

    xdg.mime = {
      enable = true;
      defaultApplications = {
        "x-scheme-handler/http" = [ "chromium-browser.desktop" ];
        "x-scheme-handler/https" = [ "chromium-browser.desktop" ];
        "text/html" = [ "chromium-browser.desktop" ];
        "application/pdf" = [
          "chromium-browser.desktop"
        ];
      };
    };
  };
}
