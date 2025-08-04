{ config, pkgs, lib, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "fufud";
  home.homeDirectory = "/home/fufud";

  home.stateVersion = "25.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # User-specific packages
    nodejs_latest  # Latest Node.js for fufud
  ];

  # Clone the.files repository on activation
  home.activation = {
    cloneDotfiles = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ ! -d "$HOME/the.files" ]; then
        echo "Cloning the.files repository..."
        $DRY_RUN_CMD ${pkgs.git}/bin/git clone https://github.com/categoricalcat/the.files.git $HOME/the.files || \
        $DRY_RUN_CMD ${pkgs.git}/bin/git clone git@github.com:categoricalcat/the.files.git $HOME/the.files
      else
        echo "the.files repository already exists"
      fi
    '';
  };
}