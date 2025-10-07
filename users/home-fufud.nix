{
  pkgs,
  lib,
  config,
  desktopEnvironment ? null,
  ...
}:

{
  imports = [ ./sshfs-the-files.nix ];

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

      gnomeExtensions.user-themes
      gnomeExtensions.dash-to-dock
      gnomeExtensions.blur-my-shell
      gnomeExtensions.appindicator
      dconf2nix
    ];

  theFilesSshfs.enable = lib.hasAttr "desktopManager" config.services;

  gtk = lib.mkIf (desktopEnvironment == "gnome") {
    enable = true;
    theme = {
      name = lib.mkDefault "Catppuccin-Macchiato-Standard-Mauve-Dark";
      package = lib.mkDefault pkgs.catppuccin-gtk;
    };
    iconTheme = {
      name = lib.mkDefault "Papirus-Dark";
      package = lib.mkDefault pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = lib.mkDefault "Bibata-Modern-Classic";
      package = lib.mkDefault pkgs.bibata-cursors;
    };
    font = {
      name = lib.mkDefault "Maple Mono NF CN";
      size = lib.mkDefault 11;
    };
  };

  # home.file.".local/share/wallpapers/nix-wallpaper.png".source = wallpaper;

  dconf = lib.mkIf (desktopEnvironment == "gnome") {
    enable = true;
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = lib.mkDefault "Catppuccin-Macchiato-Standard-Mauve-Dark";
        icon-theme = lib.mkDefault "Papirus-Dark";
        cursor-theme = lib.mkDefault "Bibata-Modern-Classic";
        font-name = lib.mkDefault "Maple Mono NF CN 11";
      };

      "org/gnome/desktop/wm/preferences" = {
        button-layout = "appmenu:minimize,maximize,close";
      };
      "org/gnome/mutter" = {
        center-new-windows = true;
      };

      "org/gnome/shell" = {
        enabled-extensions = [
          "user-theme@gnome-shell-extensions.gcampax.github.com"
          "dash-to-dock@micxgx.gmail.com"
          "blur-my-shell@aunetx"
          "appindicatorsupport@rgcjonas.gmail.com"
        ];

        favorite-apps = [
          "firefox.desktop"
          "org.gnome.Nautilus.desktop"
          "org.gnome.Console.desktop"
          "obsidian.desktop"
        ];
      };

      "org/gnome/shell/extensions/user-theme" = {
        name = lib.mkDefault "Catppuccin-Macchiato-Standard-Mauve-Dark";
      };

      "org/gnome/shell/extensions/dash-to-dock" = {
        dock-position = "BOTTOM";
        dash-max-icon-size = 48;
        intellihide = true; # Autohide the dock
        click-action = "minimize";
      };

      "org/gnome/shell/extensions/blur-my-shell" = {
        blur-overview = true;
        blur-top-panel = true;
      };
    };
  };
}
