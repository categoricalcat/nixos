{
  pkgs,
  lib,
  config,
  headless ? false,
  developer ? (!headless),
  vr ? false,
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
    ../programs/git.nix
    ../programs/ssh
    ../programs/fastfetch.nix
  ]
  ++ lib.optionals developer [
    ../programs/vscode-theme.nix
    ../programs/tui.nix
    ../programs/neovim.nix
  ];

  home = {
    packages = lib.optionals developer (
      with pkgs;
      [
        pnpm
        eslint
        typescript
        npm-check-updates
        rtk
      ]
    );

    sessionVariables = {
      TERMINFO = "/run/current-system/sw/share/terminfo";
      TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo:/run/current-system/sw/share/terminfo";
    };

    file = lib.mkMerge [
      {
        ".config/zsh" = {
          source = zshDir;
          recursive = true;
          force = true;
        };
      }
      (lib.mkIf developer {
        ".gemini/config/skills/nixos/SKILL.md".source = ../../modules/services/ai/nixos-skill.md;
        ".gemini/config/skills/code-quality/SKILL.md".source =
          ../../modules/services/ai/code-quality-skill.md;
        ".cursor/skills/nixos/SKILL.md".source = ../../modules/services/ai/nixos-skill.md;
        ".cursor/skills/code-quality/SKILL.md".source = ../../modules/services/ai/code-quality-skill.md;
        ".agents/skills/nixos/SKILL.md".source = ../../modules/services/ai/nixos-skill.md;
        ".agents/skills/code-quality/SKILL.md".source = ../../modules/services/ai/code-quality-skill.md;
      })
      (lib.mkIf vr {
        ".config/openxr/1/active_runtime.json".text = ''
          {
            "file_format_version": "1.0.0",
            "runtime": {
              "VALVE_runtime_is_steamvr": true,
              "library_path": "${config.home.homeDirectory}/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrclient.so",
              "name": "SteamVR"
            }
          }
        '';
      })
    ];

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
