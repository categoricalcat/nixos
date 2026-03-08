{
  lib,
  pkgs,
  config,
  ...
}:

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

    desktop.greeter = lib.mkOption {
      type = lib.types.enum [
        "tuigreet"
        "dms"
        "gdm"
        "none"
      ];
      default =
        if config.desktop.environment == "gnome" then
          "gdm"
        else if config.desktop.environment == "niri" then
          "tuigreet"
        else
          "none";
      description = "Greeter to use";
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
    ./desktop/greetd.nix
  ];

  config = {
    programs = {
      xwayland.enable = true;
    };

    console.keyMap = "br-abnt2";

    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";

      fcitx5.waylandFrontend = true;
      fcitx5.addons = with pkgs; [
        qt6Packages.fcitx5-chinese-addons
        fcitx5-gtk
        kdePackages.fcitx5-qt
      ];
    };

    # Critical for window managers to autostart Fcitx5
    services.xserver.desktopManager.runXdgAutostartIfNone = true;

    services.libinput.enable = true;
    services.gnome.gnome-keyring.enable = true;

    xdg.mime = {
      enable = true;
      defaultApplications = {
        "x-scheme-handler/http" = [ "floorp.desktop" ];
        "x-scheme-handler/https" = [ "floorp.desktop" ];
        "text/html" = [ "floorp.desktop" ];
        "application/pdf" = [
          "floorp.desktop"
        ];
      };
    };
  };
}
