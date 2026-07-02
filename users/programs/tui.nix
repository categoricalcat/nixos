{
  pkgs,
  ...
}:
let
  colors = import ../../modules/theme.nix;
  starshipToml =
    builtins.replaceStrings
      [
        "@base03@"
        "@base08@"
        "@base09@"
        "@base0A@"
        "@base0B@"
        "@base0D@"
        "@base0E@"
      ]
      [
        colors.base03
        colors.base08
        colors.base09
        colors.base0A
        colors.base0B
        colors.base0D
        colors.base0E
      ]
      (builtins.readFile ../assets/dotfiles/starship.toml);
in
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
        pane_frames = false;
        ui = {
          pane_frames = {
            rounded_corners = false;
            hide_session_name = true;
          };
        };
        # default_layout = "compact";
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
      historyWidget.command = "";
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
      settings = fromTOML starshipToml;
    };
  };

}
