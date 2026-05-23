{ pkgs, inputs, ... }:
let
  unstable = import ../../modules/nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
  programs.mcfly = {
    enable = true;
    package = unstable.mcfly;
  };

  programs.atuin = {
    enable = true;
    package = unstable.atuin;
  };

  programs.yazi = {
    enable = true;
    package = unstable.yazi;
  };

  programs.broot = {
    enable = true;
    package = unstable.broot;
  };

  programs.lazygit = {
    enable = true;
    package = unstable.lazygit;
  };

  programs.gitui = {
    enable = true;
    package = unstable.gitui;
  };

  programs.bottom = {
    enable = true;
    package = unstable.bottom;
  };

  programs.zellij = {
    enable = true;
    package = unstable.zellij;
  };

  programs.btop = {
    enable = true;
    package = unstable.btop.override { rocmSupport = true; };
  };

  programs.tmux = {
    enable = true;
    package = unstable.tmux;
  };

  programs.fzf = {
    enable = true;
    package = unstable.fzf;
  };

  programs.zoxide = {
    enable = true;
    package = unstable.zoxide;
  };

  programs.direnv = {
    enable = true;
    package = unstable.direnv;
    nix-direnv.enable = true;
    nix-direnv.package = unstable.nix-direnv;
  };

  home.packages = [
    unstable.starship
  ];
}
