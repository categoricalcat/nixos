{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (config.serverMode) developer;
  inherit (config.host) vr;
  agentSkills = {
    ".gemini/config/skills/nixos/SKILL.md" = ../../modules/services/ai/nixos-skill.md;
    ".gemini/config/skills/code-quality/SKILL.md" = ../../modules/services/ai/code-quality-skill.md;
    ".gemini/config/skills/etiquette/SKILL.md" = ../../modules/services/ai/etiquette-skill.md;
    ".cursor/skills/nixos/SKILL.md" = ../../modules/services/ai/nixos-skill.md;
    ".cursor/skills/code-quality/SKILL.md" = ../../modules/services/ai/code-quality-skill.md;
    ".cursor/skills/etiquette/SKILL.md" = ../../modules/services/ai/etiquette-skill.md;
    ".agents/skills/nixos/SKILL.md" = ../../modules/services/ai/nixos-skill.md;
    ".agents/skills/code-quality/SKILL.md" = ../../modules/services/ai/code-quality-skill.md;
    ".agents/skills/etiquette/SKILL.md" = ../../modules/services/ai/etiquette-skill.md;
  };
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
    ../programs/tui.nix
    ../programs/vscode-theme.nix
    ../programs/neovim.nix
    ../programs/khal.nix
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

    sessionVariables = lib.mkMerge [
      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        TERMINFO = "/run/current-system/sw/share/terminfo";
        TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo:/run/current-system/sw/share/terminfo";
      })
    ];

    file = lib.mkMerge [
      {
        ".config/zsh" = {
          source = zshDir;
          recursive = true;
          force = true;
        };
      }
      (lib.mkIf developer (
        lib.mapAttrs (_path: src: {
          source = src;
          force = true;
        }) agentSkills
      ))
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

    activation.realizeSkillFiles = lib.mkIf developer (
      lib.hm.dag.entryAfter [ "linkGeneration" ] (
        let
          skills = builtins.attrNames agentSkills;
          realizeCmds = lib.concatMapStringsSep "\n" (relPath: ''
            target="$HOME/${relPath}"
            if [ -e "$target" ] || [ -L "$target" ]; then
              src="$(readlink -f "$target")"
              dir="$(dirname "$target")"
              run install -d -m 0755 "$dir"
              run rm -f "$target"
              run install -m 0444 "$src" "$target"
            fi
          '') skills;
        in
        realizeCmds
      )
    );
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
