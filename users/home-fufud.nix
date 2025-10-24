{
  pkgs,
  lib,
  config,
  desktopEnvironment ? null,
  ...
}:

{
  imports = [
    ./sshfs-the-files.nix
    ./programs/wofi.nix
    ./programs/gnome-dconf.nix
  ];

  home.username = "fufud";
  home.homeDirectory = "/home/fufud";

  home.stateVersion = "25.11";

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
    [
      nodejs_latest
      sshfs
    ]
    ++ lib.optionals (desktopEnvironment == "gnome") [
      catppuccin-gtk
      papirus-icon-theme
      bibata-cursors
      dconf2nix
      dconf-editor
    ];

  theFilesSshfs.enable = lib.hasAttr "desktopManager" config.services;

  gtk = lib.mkIf (desktopEnvironment == "gnome") {
    enable = true;
    theme = {
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

  # home.file.".local/share/wallpapers/nix-wallpaper.png".source = wallpaper;

  # dconf moved to ./programs/gnome-dconf.nix
}
