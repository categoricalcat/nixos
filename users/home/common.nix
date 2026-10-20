{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (config.serverMode) developer;
  inherit (config.host) vr;
  agentSkillTargets = [
    ".gemini/config/skills"
    ".cursor/skills"
    ".agents/skills"
    ".claude/skills"
    ".opencode/skills"
  ];
  skills = {
    nixos = ../../modules/services/ai/nixos-skill.md;
    code-quality = ../../modules/services/ai/code-quality-skill.md;
    etiquette = ../../modules/services/ai/etiquette-skill.md;
  };
  agentSkills = lib.concatMapAttrs (
    name: path: lib.genAttrs (map (target: "${target}/${name}/SKILL.md") agentSkillTargets) (_: path)
  ) skills;
in
{
  imports = [
    ./shell.nix
    ../programs/git.nix
    ../programs/ssh
    ../programs/vscode-theme.nix
    ../programs/khal.nix
  ];

  home = {
    packages = lib.optionals developer (
      with pkgs;
      [
        npm-check-updates
        rtk
      ]
    );

    file = lib.mkMerge [
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
}
