{
  pkgs,
  lib,
  ...
}:
let
  policyRoot = ../../modules/services/ai/policies;

  policies = {
    etiquette = {
      description = "Agent work etiquette — universally binding on ALL and ANY agents: deterministic spec compliance, non-destructive verification, where plans go, finding files with fd/rg, scratch scripts in /tmp/ai, and what agents never do (git stage/commit/push/author, sudo, nixos-rebuild switch, raw ssh, reading secrets). Always active.";
      isRule = true;
      isSkill = true;
    };
    code-quality = {
      description = "Proactively detect and refactor duplicated code and cyclomatic complexity. Always active, language-agnostic.";
      isRule = true;
      isSkill = true;
      ruleRefs = [ "etiquette" ];
    };
    nixos = {
      description = "NixOS configuration, modules, options, flake management, and idiomatic functional combinators. Read local source code from /etc/nix/inputs before searching online. Always verify which host you are on.";
      isRule = false;
      isSkill = true;
      ruleRefs = [
        "etiquette"
        "code-quality"
      ];
    };
    fp-check = {
      description = "Category theory (explanations, exercises, categorical design), functional-programming abstractions (functors, monads, folds, natural transformations), formal specifications, property-based testing, dependent types, and proof assistants (Lean, Rocq, Agda, Idris). Separates generated, compiled, tested, and proven evidence. Not for routine coding outside these topics.";
      isRule = false;
      isSkill = true;
      ruleRefs = [
        "etiquette"
        "code-quality"
      ];
    };
  };

  resolvedPolicies = lib.mapAttrs (
    name: meta:
    let
      dir = policyRoot + "/${name}";
      refsDir = dir + "/references";
    in
    {
      ruleRefs = [ ];
    }
    // meta
    // {
      body = builtins.readFile (dir + "/body.md");
      references = lib.optionalAttrs (builtins.pathExists refsDir) (
        lib.mapAttrs (ref: _: refsDir + "/${ref}") (
          lib.filterAttrs (_: type: type == "regular") (builtins.readDir refsDir)
        )
      );
    }
  ) policies;

  skillPolicies = lib.filterAttrs (_: p: p.isSkill) resolvedPolicies;
  rulePolicies = lib.filterAttrs (_: p: p.isRule) resolvedPolicies;

  agentSkillDirs = [
    ".gemini/config/skills"
    ".cursor/skills"
    ".agents/skills"
    ".claude/skills"
    ".opencode/skills"
  ];

  skillFiles = skill: file: map (target: "${target}/${skill}/${file}") agentSkillDirs;
  skillPaths = name: skillFiles name "SKILL.md";
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

  makeSkillFile =
    name: policy:
    let
      inherit (policy) ruleRefs;
      linkedRules = lib.optionalString (ruleRefs != [ ]) ''

        ## Linked rules

        ${lib.concatMapStringsSep "\n" (rule: "- Follow the [${rule}](../${rule}/SKILL.md) rule.") ruleRefs}
      '';
    in
    assert lib.all (
      rule:
      lib.assertMsg (
        rulePolicies ? ${rule} && skillPolicies ? ${rule}
      ) "${name}: ruleRef ${rule} must be a rule and a skill"
    ) ruleRefs;
    assert lib.all (
      ref:
      lib.assertMsg (lib.hasInfix "](references/${ref})" policy.body) "${name}: references/${ref} is not linked from its body"
    ) (lib.attrNames policy.references);
    makePolicyFile "skill" "name: ${name}\n" name (policy // { body = policy.body + linkedRules; });
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

  referenceFiles = lib.concatMapAttrs (
    skill: policy: distribute (ref: skillFiles skill "references/${ref}") (_: lib.id) policy.references
  ) skillPolicies;

  agentFiles =
    (distribute skillPaths makeSkillFile skillPolicies)
    // (distribute rulePaths makeRuleFile rulePolicies)
    // referenceFiles;
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
