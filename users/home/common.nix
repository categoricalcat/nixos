{
  pkgs,
  inputs,
  config,
  ...
}:
let
  unstable = import ../../modules/nixpkgs-unstable.nix { inherit inputs pkgs; };

in
{
  imports = [
    inputs.thefiles.homeModules.default
    ../programs/git.nix
    ../programs/tui.nix
    ../programs/ssh
    ../programs/neovim.nix
  ];

  home = {
    packages = with pkgs; [
      unstable.zed-editor
      pnpm
      eslint
      typescript
      npm-check-updates
    ];

    sessionVariables = {
      TERMINFO = "/run/current-system/sw/share/terminfo";
      TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo:/run/current-system/sw/share/terminfo";
    };
  };

  programs = {
    home-manager.enable = true;

    zsh = {
      enable = true;
      package = unstable.zsh;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      initContent = builtins.readFile "${inputs.thefiles}/.zshrc";
    };
  };
}
