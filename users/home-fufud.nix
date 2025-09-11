{
  pkgs,
  ...
}:

let
  the-files = pkgs.fetchFromGitHub {
    owner = "categoricalcat";
    repo = "the.files";
    rev = "main";
  };
in
{
  home.username = "fufud";
  home.homeDirectory = "/home/fufud";

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    nodejs_latest
  ];

  home.file.".zshrc" = {
    source = "${the-files}/zshrc";
  };

  home.file."the.files" = {
    source = the-files;
  };
}
