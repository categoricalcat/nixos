{
  pkgs,
  lib,
  ...
}:

{
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

  home.packages = with pkgs; [
    nodejs_latest

    catppuccin-gtk
    papirus-icon-theme
    bibata-cursors

    gnomeExtensions.user-themes
    gnomeExtensions.dash-to-dock
    gnomeExtensions.blur-my-shell
    gnomeExtensions.appindicator
    dconf2nix

    sshfs
  ];

  gtk = {
    enable = true;
    theme = {
      name = "Catppuccin-Macchiato-Standard-Mauve-Dark";
      package = pkgs.catppuccin-gtk;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
    };
    font = {
      name = "Maple Mono NF CN";
      size = 11;
    };
  };

  # home.file.".local/share/wallpapers/nix-wallpaper.png".source = wallpaper;

  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "Catppuccin-Macchiato-Standard-Mauve-Dark";
        icon-theme = "Papirus-Dark";
        cursor-theme = "Bibata-Modern-Classic";
        font-name = "Maple Mono NF CN 11";
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
        name = "Catppuccin-Macchiato-Standard-Mauve-Dark";
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
