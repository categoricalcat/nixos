{ pkgs, inputs, ... }:
let
  unstable = import ../../modules/nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
  programs = {
    mcfly = {
      enable = true;
      package = unstable.mcfly;
    };

    atuin = {
      enable = true;
      package = unstable.atuin;
    };

    yazi = {
      enable = true;
      package = unstable.yazi;
    };

    broot = {
      enable = true;
      package = unstable.broot;
    };

    lazygit = {
      enable = true;
      package = unstable.lazygit;
    };

    gitui = {
      enable = true;
      package = unstable.gitui;
    };

    bottom = {
      enable = true;
      package = unstable.bottom;
    };

    zellij = {
      enable = true;
      package = unstable.zellij;
    };

    btop = {
      enable = true;
      package = unstable.btop.override { rocmSupport = true; };
    };

    tmux = {
      enable = true;
      package = unstable.tmux;
    };

    fzf = {
      enable = true;
      package = unstable.fzf;
    };

    zoxide = {
      enable = true;
      package = unstable.zoxide;
    };

    direnv = {
      enable = true;
      package = unstable.direnv;
      nix-direnv.enable = true;
      nix-direnv.package = unstable.nix-direnv;
    };
  };

  home.packages = [
    unstable.starship
  ];
}
