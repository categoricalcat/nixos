{ pkgs, lib, ... }:

{
  options = {
    desktop.environment = lib.mkOption {
      type = lib.types.enum [
        "gnome"
        "hyprland"
        "niri"
      ];
      default = "gnome";
      description = "Desktop environment to use";
    };
  };

  imports = [
    ./desktop/gnome.nix
    ./desktop/hyprland.nix
    ./desktop/niri.nix
    ./desktop/stylix.nix
  ];

  config = {
    programs = {
      xwayland.enable = true;
    };

    console.keyMap = "br-abnt2";

    services.libinput.enable = true;

    environment.systemPackages = with pkgs; [
      discord
      discord-ptb
      chromium
      firefox
      vscode-fhs
      code-cursor-fhs
      spotifyd
      zsh
      bitwarden-desktop
      git
      kitty
      ghostty
      cloudflared
      mako
      waybar
      fuzzel
      xwayland
      gnome-keyring
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
      xwayland-satellite
    ];

    xdg.mime = {
      enable = true;
      defaultApplications = {
        "x-scheme-handler/http" = [ "firefox.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" ];
        "text/html" = [ "firefox.desktop" ];
        "application/pdf" = [
          "firefox.desktop"
        ];
      };
    };
  };
}
