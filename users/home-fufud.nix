{
  pkgs,
  lib,
  ...
}:

{
  home.username = "fufud";
  home.homeDirectory = "/home/fufud";

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    nodejs_latest
  ];

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
}
