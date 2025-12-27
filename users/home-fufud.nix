{
  pkgs,
  lib,
  inputs,
  desktopEnvironment ? null,
  ...
}:
{
  imports = [
    ./programs/wofi.nix
  ]
  ++ lib.optional (desktopEnvironment == "gnome") ./programs/gnome-dconf.nix
  ++ lib.optionals (desktopEnvironment == "niri") [
    inputs.dms.homeModules.dank-material-shell
    # inputs.dms.homeModules.niri
    ./programs/dms.nix
  ];

  home.username = "fufud";
  home.homeDirectory = "/home/fufud";

  home.stateVersion = "26.05";

  programs = {
    home-manager = {
      enable = true;
    };

    alacritty = {
      enable = true;
      theme = "aura";
      settings = {
        window = {
          opacity = lib.mkDefault 0.85;
          blur = true;
        };
      };
    };

    kitty = {
      enable = true;
      settings = {
        background_opacity = lib.mkDefault "0.85";
        dynamic_background_opacity = true;
      };
    };
  };

  home.activation = {
    cloneDotfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -d "$HOME/the.files" ]; then
        echo "Cloning the.files repository..."
        $DRY_RUN_CMD ${pkgs.git}/bin/git clone https://github.com/categoricalcat/the.files.git $HOME/the.files || \
        $DRY_RUN_CMD ${pkgs.git}/bin/git clone git@github.com:categoricalcat/the.files.git $HOME/the.files
      else
        echo "the.files repository already exists"
      fi
    '';
  };

  home.packages =
    with pkgs;
    with haskellPackages;
    [
      nodejs_latest
      sshfs
      ghc
      cabal-install
      haskell-language-server
      stack
      ghcid
      joplin-desktop

    ]
    ++ lib.optionals (desktopEnvironment == "gnome") [
      catppuccin-gtk
      dconf2nix
      dconf-editor
    ]
    ++ lib.optionals (desktopEnvironment != null) [
      papirus-icon-theme
      bibata-cursors
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
          name = lib.mkDefault "Bibata-Modern-Classic-Right";
          package = lib.mkDefault pkgs.bibata-cursors;
        };
        font = {
          name = lib.mkDefault "Maple Mono NF CN";
          size = lib.mkDefault 11;
        };
      };
}
