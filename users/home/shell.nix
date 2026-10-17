{
  pkgs,
  lib,
  config,
  ...
}:
let
  zshColors = import ../../modules/theme.nix;
  zshDir = pkgs.runCommand "zsh-config" { } ''
    cp -r ${../assets/dotfiles/zsh} "$out"
    chmod -R +w "$out"
    substituteInPlace "$out/completion.zsh" \
      --replace-fail '@base03@' '${zshColors.base03}'
  '';
in
{
  imports = [
    ../../modules/options/host.nix
    ../../modules/options/server-mode.nix
    ../../modules/options/desktop.nix
    ../programs/fastfetch.nix
    ../programs/tui.nix
    ../programs/neovim.nix
  ];

  home = {
    sessionVariables = lib.mkMerge [
      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        TERMINFO = "/run/current-system/sw/share/terminfo";
        TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo:/run/current-system/sw/share/terminfo";
      })
      (lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && config.serverMode.developer) {
        EDITOR = lib.mkDefault "nvim";
        VISUAL = lib.mkDefault "nvim";
      })
    ];

    file = {
      ".config/zsh" = {
        source = zshDir;
        recursive = true;
        force = true;
      };
    };
  };

  programs = {
    home-manager.enable = true;

    zsh = {
      enable = true;
      package = pkgs.zsh;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      initContent = builtins.readFile ../assets/dotfiles/zshrc;
    };
  };
}
