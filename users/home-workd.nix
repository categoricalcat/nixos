{ pkgs, ... }:

let
  the-files = pkgs.fetchFromGitHub {
    owner = "categoricalcat";
    repo = "the.files";
    rev = "main";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
in
{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "workd";
  home.homeDirectory = "/home/workd";

  home.stateVersion = "25.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # User-specific packages
    nodejs_20
    nodePackages.pnpm
    nodePackages.eslint
    nodePackages.typescript
    nodePackages.npm-check-updates
  ];

  home.file.".zshrc" = {
    source = "${the-files}/zshrc";
  };

  home.file."the.files" = {
    source = the-files;
  };
}
