{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
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

    file = {
      ".gemini/config/skills/nixos/SKILL.md".source = ../../modules/services/ai/nixos-skill.md;
      ".cursor/skills/nixos/SKILL.md".source = ../../modules/services/ai/nixos-skill.md;
      ".config/zsh" = {
        source = ../assets/dotfiles/zsh;
        recursive = true;
        force = true;
      };
    };

    activation.realizeSshConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run install -d -m 0700 "$HOME/.ssh"
      if [ -L "$HOME/.ssh/config" ]; then
        src="$(readlink -f "$HOME/.ssh/config")"
        run rm -f "$HOME/.ssh/config"
        run install -m 0600 "$src" "$HOME/.ssh/config"
      fi
    '';
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
