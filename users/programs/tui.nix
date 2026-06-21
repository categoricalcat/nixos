{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  programs = {
    mcfly = {
      enable = true;
      package = pkgs.mcfly;
    };

    atuin = {
      enable = true;
      package = pkgs.atuin;
    };

    yazi = {
      enable = true;
      package = pkgs.yazi;
    };

    broot = {
      enable = true;
      package = pkgs.broot;
    };

    lazygit = {
      enable = true;
      package = pkgs.lazygit;
    };

    gitui = {
      enable = true;
      package = pkgs.gitui;
    };

    bottom = {
      enable = true;
      package = pkgs.bottom;
    };

    zellij = {
      enable = true;
      package = pkgs.zellij;
      settings = {
        on_force_close = "quit";
        # theme = "stylix";
        mouse_mode = true;
        copy_on_select = true;
        default_mode = "locked";
        show_startup_tips = false;
      };
    };

    btop = {
      enable = true;
      package = pkgs.btop.override { rocmSupport = true; };
    };

    tmux = {
      enable = true;
      package = pkgs.tmux;
    };

    fzf = {
      enable = true;
      package = pkgs.fzf;
    };

    zoxide = {
      enable = true;
      package = pkgs.zoxide;
    };

    direnv = {
      enable = true;
      package = pkgs.direnv;
      nix-direnv.enable = true;
      nix-direnv.package = pkgs.nix-direnv;
    };

    starship = {
      enable = true;
      settings = fromTOML (builtins.readFile "${inputs.thefiles}/.config/starship.toml");
    };
  };

  # TODO: need to migrate home config to thefiles at some point
  home.file.".config/starship.toml".enable = lib.mkForce false;
}
