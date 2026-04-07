{
  pkgs,
  lib,
  desktopEnvironment ? null,
  ...
}:
let
  homeDirectory = "/home/yi";
in
{
  imports = [
    ./common.nix
    ../programs/fastfetch.nix
  ]
  ++ lib.optionals (desktopEnvironment != null) [
    ../programs/opencode.nix
    ../programs/alacritty.nix
    ../programs/mprisence.nix
    ../../modules/desktop/web-apps.nix
  ]
  ++ lib.optional (desktopEnvironment == "gnome") ../programs/gnome-dconf.nix
  ++ lib.optionals (desktopEnvironment == "niri") [
    ../programs/dms.nix
  ];

  home.username = "yi";
  home.homeDirectory = homeDirectory;

  home.packages =
    with pkgs;
    with haskellPackages;
    [
      bun
      nodejs

      sshfs
      ghc
      cabal-install
      haskell-language-server
      stack
      ghcid

    ]
    ++ lib.optionals (desktopEnvironment == "gnome") [
      catppuccin-gtk
      dconf2nix
      dconf-editor

      gnomeExtensions.appindicator
      gnomeExtensions.dash-to-panel
      gnomeExtensions.gtile
      gnomeExtensions.media-controls
      gnomeExtensions.weather-oclock
    ]
    ++ lib.optionals (desktopEnvironment != null) [
      papirus-icon-theme
      bibata-cursors
      joplin-desktop
    ];

  gtk =
    lib.mkIf
      (desktopEnvironment == "gnome" || desktopEnvironment == "kde" || desktopEnvironment == "niri")
      {
        enable = true;
        theme = lib.mkIf (desktopEnvironment == "gnome") {
          name = lib.mkDefault "Catppuccin-Mocha-Standard-Lavender-Dark";
          package = lib.mkDefault pkgs.catppuccin-gtk;
        };
        iconTheme = {
          name = lib.mkDefault "Papirus-Dark";
          package = lib.mkDefault pkgs.papirus-icon-theme;
        };
        cursorTheme = {
          name = lib.mkDefault "Bibata-Modern-Amber-Right";
          package = lib.mkDefault pkgs.bibata-cursors;
        };
        font = {
          name = lib.mkDefault "Maple Mono NF CN";
          size = lib.mkDefault 11;
        };
      };
}
