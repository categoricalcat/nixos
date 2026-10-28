{
  pkgs,
  lib,
  ...
}:
let
  policies = {
    etiquette = {
      description = "Agent work etiquette — universally binding on ALL and ANY agents: deterministic spec compliance, non-destructive verification, where plans go, finding files with fd/rg, scratch scripts in /tmp/ai, and what agents never do (git stage/commit/push/author, sudo, nixos-rebuild switch, raw ssh, reading secrets). Always active.";
      body = builtins.readFile ../../modules/services/ai/etiquette.md;
      isRule = true;
      isSkill = true;
    };
    code-quality = {
      description = "Proactively detect and refactor duplicated code and cyclomatic complexity. Always active, language-agnostic.";
      body = builtins.readFile ../../modules/services/ai/code-quality.md;
      isRule = true;
      isSkill = true;
    };
    nixos = {
      description = "NixOS configuration, modules, options, flake management, and idiomatic functional combinators. Read local source code from /etc/nix/inputs before searching online. Always verify which host you are on.";
      body = builtins.readFile ../../modules/services/ai/nixos.md;
      isRule = false;
      isSkill = true;
    };
  };

  skillPolicies = lib.filterAttrs (_: p: p.isSkill) policies;
  rulePolicies = lib.filterAttrs (_: p: p.isRule) policies;

  agentSkillDirs = [
    ".gemini/config/skills"
    ".cursor/skills"
    ".agents/skills"
    ".claude/skills"
    ".opencode/skills"
  ];

  skillPaths = name: map (target: "${target}/${name}/SKILL.md") agentSkillDirs;
  rulePaths = name: [
    ".cursor/rules/${name}.mdc"
    ".claude/rules/${name}.md"
    ".agents/rules/${name}.md"
    ".gemini/config/rules/${name}.md"
    ".opencode/rules/${name}.md"
  ];

  makePolicyFile =
    kind: extraFrontmatter: name: policy:
    pkgs.writeText "${name}-${kind}.md" ''
      ---
      ${extraFrontmatter}description: ${builtins.toJSON policy.description}
      ---

      ${policy.body}
    '';

  makeSkillFile = name: policy: makePolicyFile "skill" "name: ${name}\n" name policy;
  makeRuleFile = name: policy: makePolicyFile "rule" "alwaysApply: true\n" name policy;

  distribute =
    pathsFor: makeFile: policySet:
    lib.concatMapAttrs (
      name: policy:
      let
        file = makeFile name policy;
      in
      lib.genAttrs (pathsFor name) (_: file)
    ) policySet;

  agentFiles =
    (distribute skillPaths makeSkillFile skillPolicies)
    // (distribute rulePaths makeRuleFile rulePolicies);
in
{
  home = {
    file = lib.mapAttrs (_path: src: {
      source = src;
      force = true;
    }) agentFiles;

    activation.realizeAgentPolicies = lib.hm.dag.entryAfter [ "linkGeneration" ] (
      let
        files = builtins.attrNames agentFiles;
        fileListStr = lib.concatMapStringsSep "\n" (f: "  ${lib.escapeShellArg f}") files;
      in
      ''
        files=(
        ${fileListStr}
        )
        for relPath in "''${files[@]}"; do
          target="$HOME/$relPath"
          if [ -e "$target.bkp" ]; then
            run rm -f "$target.bkp"
          fi
          if [ -L "$target" ]; then
            src="$(readlink -f "$target")"
            dir="$(dirname "$target")"
            run install -d -m 0755 "$dir"
            run rm -f "$target"
            run install -m 0444 "$src" "$target"
          fi
        done
      ''
    );
  };
}
