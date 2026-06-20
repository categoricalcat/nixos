{
  pkgs,
  inputs,
  config,
  ...
}:
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
      pnpm
      eslint
      typescript
      npm-check-updates
    ];

    sessionVariables = {
      TERMINFO = "/run/current-system/sw/share/terminfo";
      TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo:/run/current-system/sw/share/terminfo";
    };

    file.".gemini/config/skills/nixos/SKILL.md".source = ../../modules/services/ai/nixos-skill.md;
    file.".cursor/skills/nixos/SKILL.md".source = ../../modules/services/ai/nixos-skill.md;
  };

  programs = {
    home-manager.enable = true;

    zsh = {
      enable = true;
      package = pkgs.zsh;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      initContent = builtins.readFile "${inputs.thefiles}/.zshrc";
    };
  };
}
