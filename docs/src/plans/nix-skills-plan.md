# Nix Skill and Review Policy Upgrade Plan

Status: Ready for implementation

## Objective

Upgrade the repository's [`nixos`](../../modules/services/ai/policies/nixos/body.md) skill, align the companion policies ([`etiquette`](../../modules/services/ai/policies/etiquette/body.md), [`code-quality`](../../modules/services/ai/policies/code-quality/body.md), [`fp-check`](../../modules/services/ai/policies/fp-check/body.md), and [`users/home/ai-policies.nix`](../../users/home/ai-policies.nix)) with [`AGENTS.md`](../../AGENTS.md), and remediate existing repository `.nix` files so AI agents and the codebase adhere to authoritative Nix, NixOS, Nixpkgs, and `flake-parts` standards.

## Current state

1. **Policy topology ([`users/home/ai-policies.nix`](../../users/home/ai-policies.nix) & [`AGENTS.md`](../../AGENTS.md)):**

   - Defines four canonical policies under `modules/services/ai/policies/<name>/`:
     - `etiquette` (`isRule = true; isSkill = true;`) — operational safety, git boundaries, scratch scripts, and non-destructive verification (`statix check`, `deadnix`, `nix flake check --no-build`).
     - `code-quality` (`isRule = true; isSkill = true; ruleRefs = [ "etiquette" ];`) — language-agnostic DRY, cyclomatic complexity, *No Representation Bouncing*, and indirection rules.
     - `fp-check` (`isRule = false; isSkill = true; ruleRefs = [ "etiquette" "code-quality" ];`) — category theory, property-based testing, and proof assistants, routed via on-demand `references/` (`category-theory.md`, `verification.md`, `haskell.md`). Explicitly states: *"Not for routine coding outside these topics."*
     - `nixos` (`isRule = false; isSkill = true; ruleRefs = [ "etiquette" "code-quality" ];`) — currently covers host identification (`hostname`), `ai-ssh <host>`, reading `/etc/nix/inputs` before searching online, not guessing options, and three bullets on `AttrSet`/product/list combinators (`lib.concatMapAttrs`, `lib.genAttrs`, `lib.mapAttrs'`, `lib.mergeAttrsList`, `lib.cartesianProduct`, `lib.concatMap`).
   - `makeSkillFile` enforces two evaluation-time assertions on every skill:
     - Every entry in `ruleRefs` must exist in both `rulePolicies` and `skillPolicies`.
     - Every regular file in `modules/services/ai/policies/<name>/references/` must be linked in `body.md` using the exact substring `](references/${ref})`.
   - `AGENTS.md` mandates:
     - *"Skills are self-contained: they link only to the always-on rules (`ruleRefs`), never to other skills."*
     - *"Skills never restate the rules they link; they add only domain-specific guidance."*

1. **Cross-policy friction and inconsistencies:**

   - **`nixos/body.md` restates `etiquette`:** `nixos/body.md` §1.5 (*Cross-Host Access (read-only)*) duplicates `etiquette/body.md` §4–§5 (`ai-ssh <host> <command>`, `docs/src/services/ai-ssh.md`, never raw `ssh`/`scp`/`sshfs`/`mosh`/`rsync`, never `nixos-rebuild --target-host`/`--build-host`), violating `AGENTS.md`'s rule against restating linked rules. Sections §2–§5 in `nixos/body.md` are also fragmented into one-sentence headings.
   - **`code-quality/body.md` formatting & Nix calibration:**
     - Line 25 of `code-quality/body.md` contains double-escaped LaTeX (`$d \\le 1$` and `$R \\circ R = R$`) in raw Markdown, which `builtins.readFile` copies verbatim into generated skill/rule files (causing KaTeX to render `\\` as a newline rather than `\le` and `\circ`).
     - `code-quality/body.md` starts with `# Code Quality` (H1) while `etiquette/body.md` starts with `## Universal Scope & Invariance` (H2), causing `zedInstructions` in `users/home/ai-policies.nix` (`# ${name}\n\n${policy.body}`) to emit duplicate H1 headings for `code-quality`.
     - `code-quality` §2–§3 uses imperative terms (*"early returns/guard clauses over nesting"*, *"no single-consumer intermediate bindings"*) that need explicit Nix-domain translation in `nixos/body.md` (where module attribute paths are structural data, conditionals use lazy `lib.mkIf`/`lib.mkMerge`, `let cfg = config.services.<name>;` is standard when referenced 2+ times, and `finalAttrs:` replaces single-use `pname`/`version` bindings).
   - **`etiquette/body.md` internal tension & linter drift:**
     - `etiquette/body.md` §3 mentions only `statix check` and `deadnix`, omitting `nixf-diagnose`, `nixfmt --check`, and `treefmt --fail-on-change` enforced by `nix/treefmt.nix` and `nix/git-hooks.nix`.
     - `etiquette/body.md` §1 requires deleting finished plans in `docs/src/plans/<topic>-plan.md`, whereas §8 begins with the broad label `**Never delete files or scratch artifacts**` when its body specifically targets `/tmp/ai/`.
   - **`users/home/ai-policies.nix` single-consumer chain:** Lines 154–161 bind `files = builtins.attrNames agentFiles;` solely to feed `fileListStr`, which is itself used once—violating `code-quality` §3 (*No intermediate indirection chains*).

1. **Nix-specific gaps not covered by existing skills or linters:**

   - **NixOS module evaluation & fixed-point traps:** Conditioning `imports` on `config` (infinite recursion); using strict `if/else` or `lib.recursiveUpdate` instead of `lib.mkIf` / `lib.mkMerge` inside module `config`; merging two `lib.mkIf` blocks with shallow `//` (which silently drops the first `mkIf` because `mkIf` returns an attrset tag); putting `config`-dependent values in `specialArgs`; and Import From Derivation (IFD) blocking evaluation.
   - **Path coercion & `/nix/store` side effects:** Interpolating paths (`"${./dir}"`, `import "${./file}"`, or passing a path literal to `lib.escapeShellArg`) copies entire files/directories into the world-readable `/nix/store` at evaluation time, whereas `toString ./path` and `dir + "/subpath"` do not; using legacy `lib.cleanSource` or raw `./.` instead of lazy `lib.fileset.toSource`.
   - **Secrets in `/nix/store`:** Baking sensitive values or `builtins.readFile` secrets into Nix strings/derivations (`0444` in `/nix/store`) instead of runtime paths (`config.sops.secrets.<name>.path` via systemd `LoadCredential` / `EnvironmentFile` or service-native file references like `{file:/run/secrets/...}`).
   - **Packaging & overlay conventions:** Using `rec { ... }` instead of `stdenv.mkDerivation (finalAttrs: { ... })` (e.g., `packages/zero-parades/default.nix`); omitting `strictDeps = true`; mixing `final` and `prev` in overlays; using raw `"${pkg}/bin/foo"` instead of `lib.getExe` / `lib.getExe'`; and using legacy hex `sha256` instead of SRI `hash = "sha256-..."`.
   - **Shell-in-Nix blind spot:** `treefmt` only runs `shellcheck`/`shfmt`/`shellharden` on `.sh` files, leaving multiline bash strings inside `.nix` files (`systemd.services.*.script`, `installPhase`, `pkgs.writeShellScriptBin`) unchecked unless wrapped with `pkgs.writeShellApplication` or extracted to `.sh` files.
   - **`flake-parts` scoping:** Hardcoding `self.packages.x86_64-linux.<pkg>` inside `perSystem` (e.g., `flake.nix` line 118) instead of using `config.packages.<pkg>` or `self'.packages.<pkg>`.

## Decisions

1. **Keep `/nixos` as the single unified Nix skill (`r. keep /nixos.`):**

   - Keep Nix authoring, refactoring, and review unified inside `nixos` (with on-demand `references/*.md`, mirroring `fp-check`'s progressive disclosure) rather than creating a separate `nix-review` skill that cannot link to `nixos` under `AGENTS.md`.
   - Deduplicate `nixos/body.md` against `etiquette/body.md` so `nixos` never restates linked rules (`etiquette` §4–§6) and instead contributes only Nix/NixOS-specific rules.

1. **Align `etiquette`, `code-quality`, and `fp-check` without blurring domain boundaries:**

   - Fix the LaTeX double-backslash bug and top-level heading level in `code-quality/body.md` so `.config/zed/AGENTS.md` and skill files render cleanly.
   - Update `etiquette/body.md` §3 (full linter suite + `treefmt --fail-on-change`) and §8 (`**Never delete scratch files in /tmp/ai/**` so it does not conflict visually with §1 plan retirement).
   - Keep `fp-check/body.md` and its `references/` unchanged, while aligning `nixos/references/review-checklist.md`'s evidence ladder (`Generated` → `Linted & formatted` → `Evaluated` → `Built` → `VM / runtime-tested`) with the repository's verification concepts without cross-linking skills.

1. **Ground all Nix guidance in primary upstream standards:**

   - **Language & anti-patterns:** [`nix.dev/guides/best-practices`](https://nix.dev/guides/best-practices) and **RFC 45** (quoted URLs, no `rec`, no top-level/escaping `with`, no `<nixpkgs>` channels).
   - **Formatting:** **RFC 166** (`nixfmt`).
   - **Module system:** [NixOS Manual — Writing NixOS Modules](https://nixos.org/manual/nixos/stable/#sec-writing-modules), [`nix.dev/tutorials/module-system`](https://nix.dev/tutorials/module-system), and **RFC 42** (`settings` options backed by `pkgs.formats.<fmt> {}`).
   - **Packaging & library docs:** [Nixpkgs Manual — Coding Conventions](https://nixos.org/manual/nixpkgs/stable/#chap-conventions) (`finalAttrs`, `strictDeps`, `lib.getExe`, `pkgs.writeShellApplication`, `lib.mkPackageOption`, `lib.fileset`), **RFC 140** (`pkgs/by-name`), **RFC 145** (`nixdoc` `/** ... */` doc-comments), and [Noogle (`noogle.dev`)](https://noogle.dev/) for `builtins`/`lib` discovery.
   - **Flake architecture:** [`flake.parts` module arguments (`self'`, `inputs'`, `config`, `withSystem`)](https://flake.parts/module-arguments.html).

1. **Remediate existing repository `.nix` files (`r. fix all.`):**

   - Clean up the concrete anti-patterns identified across `users/home/ai-policies.nix`, `flake.nix`, `nix/treefmt.nix`, `nix/devshell.nix`, `packages/zero-parades/default.nix`, and `packages/fluxer/default.nix`.

## Phases

### Phase 1: Broaden `nixos` metadata and clean up `users/home/ai-policies.nix`

In [`users/home/ai-policies.nix`](../../users/home/ai-policies.nix):

1. Update `policies.nixos.description` so agents load `/nixos` whenever authoring, refactoring, or reviewing Nix code, modules, packages, overlays, or flakes:

   ```nix
   nixos = {
     description = "Authoring, refactoring, and reviewing Nix code, NixOS/Home Manager modules, packages, overlays, and flakes. Read local source code from /etc/nix/inputs before searching online, follow nix.dev/Nixpkgs/RFC 166 conventions, and verify which host you are on.";
     isRule = false;
     isSkill = true;
     ruleRefs = [
       "etiquette"
       "code-quality"
     ];
   };
   ```

1. Inline the single-consumer `files` binding in `realizeAgentPolicies` (lines 154–161) to comply with `code-quality` §3 (*No intermediate indirection chains*).

### Phase 2: Upgrade and deduplicate `modules/services/ai/policies/nixos/body.md`

Restructure [`modules/services/ai/policies/nixos/body.md`](../../modules/services/ai/policies/nixos/body.md) so it obeys `AGENTS.md` (no restatement of `etiquette` §4–§6):

1. **§1 Host & Mesh Context:**
   - Keep host verification (`hostname` once per session when unknown; host configs under `hosts/<hostname>/configuration.nix`; state target host when editing a remote host's config).
   - Fold in the single NixOS-specific cross-host rule from old §1.5: use `ai-ssh <host>` directly to inspect remote systemd units, journals, or host state without running local `hostname` first (removing the duplicated `etiquette` §4–§5 bullets).
1. **§2 Local Inputs First (`/etc/nix/inputs`), Authoritative Online Fallback Second:**
   - Consolidate old §2–§5: always inspect `/etc/nix/inputs` (`nixpkgs`, `home-manager`, `stylix`, `sops-nix`, `flake-parts`, etc.) before searching online, and never guess option names, types, or module internals.
   - When `/etc/nix/inputs` does not contain the answer, consult primary upstream sources: `nix.dev` (*Best Practices*, *Module System*), NixOS Manual (*Writing NixOS Modules*), Nixpkgs Manual (*Coding Conventions*), RFC 42 (`settings` / `pkgs.formats`), RFC 45 (quoted URLs), RFC 140 (`pkgs/by-name`), RFC 145 (`nixdoc`), RFC 166 (`nixfmt`), `flake.parts` documentation, and `noogle.dev`.
1. **§3 Functional Combinators & `code-quality` in Nix:**
   - Preserve the `AttrSet` monoid (`lib.concatMapAttrs`, `lib.genAttrs`, `lib.mapAttrs'`, `lib.mergeAttrsList`), applicative product (`lib.cartesianProduct`), and list (`lib.concatMap`) rules.
   - Calibrate `code-quality` for Nix:
     - Deep attribute paths (`services.foo.bar = ...`) are structural data, not control-flow nesting; module conditionals must use lazy `lib.mkIf` / `lib.mkMerge` rather than strict `if/else` on `config`.
     - `let cfg = config.services.<name>; in` is idiomatic when `cfg` has 2+ consumers; inline single-use `let` bindings, and use `stdenv.mkDerivation (finalAttrs: ...)` instead of single-use `pname`/`version` bindings.
     - `packages/<name>/default.nix`, `hosts/<host>/`, and `modules/services/ai/policies/<name>/body.md` are framework entrypoints exempted from `code-quality`'s single-file folder rule.
1. **§4 Core Nix Invariants (always active on any Nix task):**
   - **Scoping:** Never introduce `rec { ... }` (use `let ... in` or `finalAttrs:`); never place `with` at file/module top level or chain/nest `with` scopes (prefer `inherit (pkgs) ...;` or explicit `pkgs.<name>`).
   - **Purity & paths:** Never use `<nixpkgs>` lookup paths or unquoted URLs (RFC 45). Never interpolate local paths into strings (`"${./dir}"`, `import "${./file}"`, or `lib.escapeShellArg ./path`) unless an immediate `/nix/store` copy is intended; use literal paths for `import`, `dir + "/subpath"` or `toString ./path` for path manipulation, and `lib.fileset.toSource` (or `dontUnpack = true`) for local derivation sources.
   - **Store secret hygiene:** Anything interpolated into a Nix string or read via `builtins.readFile` is copied world-readable (`0444`) into `/nix/store`. Wire runtime secret paths (`config.sops.secrets.<name>.path`) via systemd `LoadCredential` / `EnvironmentFile` or service-native file directives.
   - **Module laziness & merging:** Never condition `imports` on `config`; never merge `lib.mkIf` blocks with shallow `//`; avoid Import From Derivation (IFD).
   - **Executables & shell-in-Nix:** Prefer `lib.getExe` / `lib.getExe'` over `"${pkg}/bin/..."`; prefer `pkgs.writeShellApplication` (or standalone `.sh` files checked by `treefmt`) over `writeShellScriptBin` or unchecked multiline bash strings.
1. **§5 Route the Task:**
   - **Write or refactor NixOS, Home Manager, or `flake-parts` modules:** read `[references/module-patterns.md](references/module-patterns.md)`.
   - **Write or update packages, overlays, or embedded shell scripts:** read `[references/packaging-and-shell.md](references/packaging-and-shell.md)`.
   - **Review Nix diffs, audit anti-patterns, or verify changes:** read `[references/review-checklist.md](references/review-checklist.md)`.

### Phase 3: Create on-demand reference files in `modules/services/ai/policies/nixos/references/`

1. **`modules/services/ai/policies/nixos/references/module-patterns.md`:**

   - **Module anatomy & naming:** `{ config, lib, pkgs, ... }:`, `let cfg = config.services.<name>; in` (when referenced 2+ times), `{ imports; options; config; }`, `lowerCamelCase` option names.
   - **Fixed-point & laziness rules:**
     - Keep `imports` completely static (never `lib.optionals config.foo.enable [ ./bar.nix ]`; import unconditionally and gate inside `./bar.nix` with `config = lib.mkIf cfg.enable { ... }`).
     - Never combine `lib.mkIf` blocks with `//` (`(lib.mkIf a { ... }) // (lib.mkIf b { ... })` overwrites the first `mkIf`'s `_type = "if"` attrset); always wrap multiple conditional blocks in `lib.mkMerge [ ... ]`.
     - Use `lib.mkBefore`, `lib.mkAfter`, or `lib.mkOrder` for ordered list/string merging across modules.
     - Keep `specialArgs` / `extraSpecialArgs` strictly for static flake inputs (`inputs`, `global`); never pass `config`-derived values through `specialArgs`.
   - **Option declarations (RFC 42 & `lib.types`):**
     - Use `lib.mkEnableOption`, `lib.mkPackageOption pkgs "<pkg>" { ... }`, and strict `lib.types` (`submodule`, `attrsOf`, `enum`, `port`, `path`, `ints.unsigned`) rather than untyped `attrs` or unconstrained `str`.
     - For services with structured config files (JSON, YAML, TOML, INI), follow **RFC 42**: expose a `settings` option typed with `(pkgs.formats.<fmt> { }).type` and generate the config file with `(pkgs.formats.<fmt> { }).generate`.
     - Add `assertions` (and `warnings`) for host/option invariants.
   - **Override priorities & side effects:**
     - Use `lib.mkDefault` (priority 1000) in shared role/profile modules, normal definitions (priority 100) in host configs, and `lib.mkForce` (priority 50) only when overriding an upstream module without a dedicated option—always with a comment explaining why.
     - Never open firewall ports (`networking.firewall.*`) or add packages to `environment.systemPackages` unconditionally inside a service module unless gated by an option (such as `openFirewall`).
   - **Runtime secret binding & systemd hardening:**
     - Bind `config.sops.secrets.<name>.path` at runtime via `LoadCredential` (preferred) or `EnvironmentFile`, never via `systemd.services.<name>.environment` or store files.
     - Prefer `DynamicUser = true` (or dedicated system user/group), explicit `StateDirectory` / `CacheDirectory` / `RuntimeDirectory`, and `pkgs.testers.runNixOSTest` VM tests for non-trivial network/daemon modules.
   - **`flake-parts` scoping:**
     - Inside `perSystem = { config, self', inputs', pkgs, ... }:`, reference local packages/checks via `config.packages.<name>` or `self'.packages.<name>`, never `self.packages.x86_64-linux.<name>`. Use `withSystem` when bridging top-level `flake` outputs to `perSystem`.

1. **`modules/services/ai/policies/nixos/references/packaging-and-shell.md`:**

   - **Derivation structure (`callPackage` & `finalAttrs`):**
     - Accept only required dependencies in the function header (`{ lib, stdenv, fetchFromGitHub, ... }:`).
     - Use `stdenv.mkDerivation (finalAttrs: { ... })` (and `buildPythonPackage (finalAttrs: { ... })` when self-referencing attributes like `version`) instead of `rec { ... }` so `.overrideAttrs` sees updated `pname`, `version`, and `src`.
     - Set `strictDeps = true;` and separate `nativeBuildInputs` (compilers, `pkg-config`, `makeWrapper`, `copyDesktopItems`, build hooks) from `buildInputs` (target libraries) and `propagatedBuildInputs`.
   - **Sources, fetchers, and `lib.fileset`:**
     - Always use SRI hashes (`hash = "sha256-..."`; never legacy hex `sha256 = "..."`).
     - For local sources, prefer `lib.fileset.toSource { root = ./.; fileset = lib.fileset.unions [ ... ]; }` (or `dontUnpack = true;` when only substituting explicit files) over raw `src = ./.;` or `lib.cleanSource` so edits to `default.nix` or sibling files do not trigger unnecessary rebuilds or store copies.
   - **Executables, phases, and `meta`:**
     - Reference package binaries with `lib.getExe pkg` or `lib.getExe' pkg "bin-name"` rather than `"${pkg}/bin/..."`.
     - Always include `runHook preInstall` / `runHook postInstall` (and `preBuild`/`postBuild`) when defining custom phase scripts so setup hooks (`copyDesktopItems`, `autoPatchelfHook`, etc.) run.
     - Populate `meta` (`description`, `homepage`, `license` from `lib.licenses`, `platforms` from `lib.platforms`, and `mainProgram`) without `with lib;`.
     - For reusable `lib` functions, use **RFC 145** `/** ... */` doc-comments.
   - **Overlays (`final: prev:`):**
     - When modifying an existing package, always call `prev.<pkg>.override` or `prev.<pkg>.overrideAttrs` (using `final.<pkg>` recurses infinitely).
     - When calling dependencies or `callPackage`, use `final` (`final.callPackage`, `final.<dep>`) when downstream overrides should propagate through the fixpoint, or `prev.callPackage` when intentionally isolating a standalone package.
     - Always document *why* an overlay patch or workaround exists and link the upstream issue/PR so stale overlays can be retired on upgrade.
   - **Shell-in-Nix hygiene:**
     - `nix/treefmt.nix` runs `shellcheck`, `shfmt`, and `shellharden` only on `.sh` files—inline Nix multiline strings (`'' ... ''`) bypass `treefmt`'s shell linters.
     - Prefer `pkgs.writeShellApplication { name = "..."; runtimeInputs = [ ... ]; text = ''...''; }` (which sets `set -euo pipefail`, prepends `runtimeInputs` to `PATH`, and runs `shellcheck` at build time) or standalone `.sh` files loaded via `builtins.readFile ./script.sh` over `pkgs.writeShellScriptBin` or raw heredocs.
     - When inline `systemd.services.<name>.script` or phase strings are used, quote all shell expansions (`"$var"`), escape Nix-interpolated strings with `lib.escapeShellArg` / `lib.escapeShellArgs` (noting that passing a raw Nix path literal to `escapeShellArg` copies it to `/nix/store`), and include `set -euo pipefail` when appropriate.

1. **`modules/services/ai/policies/nixos/references/review-checklist.md`:**

   - **Pass 1 — Automated static & formatting checks:**

     - Run `deadnix <files>`, `nixf-diagnose <files>`, `statix check <files>`, and `nixfmt --check <files>` (or `treefmt --fail-on-change`).
     - For standalone `.sh` scripts touched alongside `.nix` files, run `shellcheck`, `shfmt -d -i 2`, and `shellharden --check`.
     - For custom derivations under `packages/*`, run `nixpkgs-hammer` when applicable.

   - **Pass 2 — Semantic & architectural review checklist:**

     - **Laziness & recursion:** Are `imports` static? Are module conditionals using `lib.mkIf` / `lib.mkMerge` rather than strict `if/else` or `//` on `mkIf`? Is `specialArgs` free of `config` values? Is there any IFD?
     - **Scoping & merging:** Any `rec { ... }` or file-level/nested `with`? Any shallow `//` clobbering nested attribute sets where module merging or `lib.recursiveUpdate` is needed? Any `lib.mkForce` missing an explanatory comment?
     - **Store copies & secrets:** Any unintended `"${./dir}"`, `import "${./file}"`, or `escapeShellArg ./path` copying local trees to `/nix/store`? Any local `src = ./.;` that should use `lib.fileset.toSource` or `dontUnpack = true`? Any secret material leaked into `/nix/store` strings instead of `sops-nix` + `LoadCredential`/`EnvironmentFile`?
     - **Packaging & overlays:** Does `mkDerivation` use `finalAttrs:` (when self-referencing) and `strictDeps = true`? Are `nativeBuildInputs` and `buildInputs` separated? Do custom phases run `runHook pre*`/`post*`? Do overlays modify `prev.<pkg>` while pulling dependencies appropriately, with upstream issue links?
     - **Shell-in-Nix & executables:** Are binaries referenced via `lib.getExe` / `lib.getExe'`? Could inline `writeShellScriptBin` / `systemd.services.*.script` blocks use `pkgs.writeShellApplication` or `.sh` files so `shellcheck` covers them? Are shell variables quoted and Nix arguments escaped?
     - **Combinators & `flake-parts`:** Does data transformation stay in the `AttrSet` monoid (`lib.concatMapAttrs`, `lib.genAttrs`, `lib.mapAttrs'`, `lib.mergeAttrsList`, `lib.cartesianProduct`) without representation bouncing? Does `perSystem` use `config.packages` / `self'` rather than `self.packages.x86_64-linux`?

   - **Pass 3 — Nix Evidence Ladder (report the exact level reached):**

     | Evidence level          | Commands to run                                                                                              | What it establishes                                                           | What remains unverified                                               |
     | ----------------------- | ------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------- | --------------------------------------------------------------------- |
     | **Generated**           | *(none)*                                                                                                     | An edit was proposed                                                          | Syntax, formatting, evaluation, build, and runtime behavior           |
     | **Linted & formatted**  | `deadnix`, `nixf-diagnose`, `statix check`, `nixfmt --check` (or `treefmt --fail-on-change`)                 | Valid syntax, RFC 166 formatting, no dead bindings or local AST anti-patterns | Module evaluation, option types, derivation builds, runtime behavior  |
     | **Evaluated**           | `nix flake check --no-build` or `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath` | Module fixpoint converges, option types and `assertions` pass, no IFD/cycles  | Derivation compilation, `writeShellApplication` `shellcheck`, runtime |
     | **Built**               | `nix build <flakeref>` or `nixos-rebuild build --flake .#<host>`                                             | Derivations compile, patch/fixup hooks and build-time `shellcheck` succeed    | Live systemd service startup, networking, hardware/GPU state          |
     | **VM / runtime-tested** | `nix build .#checks.x86_64-linux.<test>` (`pkgs.testers.runNixOSTest`)                                       | Multi-unit systemd & network behavior inside a QEMU NixOS VM                  | Physical host hardware, secrets decryption on target, external mesh   |

### Phase 4: Align `etiquette/body.md` and `code-quality/body.md`

1. **In [`modules/services/ai/policies/etiquette/body.md`](../../modules/services/ai/policies/etiquette/body.md):**
   - Update §3 line 25 to include `treefmt --fail-on-change`, `deadnix`, `nixf-diagnose`, `statix check`, and `nixfmt --check`.
   - Clarify §8 line 60 bold lead-in from `**Never delete files or scratch artifacts**:` to `**Never delete scratch files in /tmp/ai/**:` so it does not visually conflict with §1's mandate to delete finished plans in `docs/src/plans/`.
1. **In [`modules/services/ai/policies/code-quality/body.md`](../../modules/services/ai/policies/code-quality/body.md):**
   - Remove the redundant top-level `# Code Quality` H1 (matching `etiquette/body.md` so `zedInstructions` in `users/home/ai-policies.nix` does not emit duplicate H1 headings).
   - Fix the double-backslash LaTeX escaping in §3 (`$d \le 1$` and `$R \circ R = R$`).

### Phase 5: Remediate existing repository `.nix` files (`r. fix all.`)

1. **[`flake.nix`](../../flake.nix):**
   - In `perSystem` (line 113–119), add `config` to the `perSystem` module arguments and replace `default = self.packages.x86_64-linux.zero-parades;` with `default = config.packages.zero-parades;`.
1. **[`nix/treefmt.nix`](../../nix/treefmt.nix):**
   - Replace `pkgs.writeShellScriptBin "statix-fix"` with `pkgs.writeShellApplication` and replace `"${pkgs.shellharden}/bin/shellharden"` with `lib.getExe pkgs.shellharden`.
1. **[`nix/devshell.nix`](../../nix/devshell.nix):**
   - Remove `with pkgs;` in `rustPkgs` and `nixDevPkgs` (use `inherit (pkgs)` or explicit `pkgs.<name>`).
   - Replace `pkgs.writeShellScriptBin` for `nixosRebuildWrapper` and the `./scripts/*.sh` wrappers with `pkgs.writeShellApplication` (or `lib.mapAttrsToList` over a declarative table of script wrappers to eliminate the 8 repeated `writeShellScriptBin` lines per `code-quality` §1 DRY) and use `lib.getExe`.
1. **[`packages/zero-parades/default.nix`](../../packages/zero-parades/default.nix):**
   - Replace `python3.pkgs.buildPythonPackage rec` on `fsb5` with `python3.pkgs.buildPythonPackage (finalAttrs: { ... })`.
   - Replace legacy hex `sha256 = "5daf0c8a979e166f8189038d73c57fb5aa16ea1097da8f4cbdd7180468a0c337";` on `unitypy` with SRI `hash = "sha256-Xa8MipdeFm+BiQONc8V/tarG6hCX2o9MvdcYBGigwzc=";` and remove `with python3.pkgs;`.
   - In the top-level `stdenv.mkDerivation`, add `strictDeps = true;`, `runHook preInstall` / `runHook postInstall`, replace the raw heredoc dispatcher with `pkgs.writeShellApplication` (or clean `substituteInPlace`), and replace `meta = with lib; { ... }` with `meta = { description = ...; platforms = lib.platforms.linux; mainProgram = "zero-parades"; };`.
1. **[`packages/fluxer/default.nix`](../../packages/fluxer/default.nix):**
   - Replace `src = ./.;` (which copies the whole directory including `default.nix` into `/nix/store`) with `dontUnpack = true;` (since `installPhase` substitutes `./fluxer-launcher.sh` and copies `./fluxer.png` directly) and add `strictDeps = true;`.
   - Use `lib.getExe curl`, `lib.getExe jq`, and `lib.getExe appimage-run` instead of `"${pkg}/bin/..."`.
   - Replace `meta = with lib; { ... }` with explicit `lib.licenses.*`.

## Rollout order

1. Create `modules/services/ai/policies/nixos/references/module-patterns.md`, `modules/services/ai/policies/nixos/references/packaging-and-shell.md`, and `modules/services/ai/policies/nixos/references/review-checklist.md` (Phase 3).
1. Update `modules/services/ai/policies/nixos/body.md` (Phase 2), `modules/services/ai/policies/etiquette/body.md` and `modules/services/ai/policies/code-quality/body.md` (Phase 4), and `users/home/ai-policies.nix` (Phase 1).
1. Remediate `flake.nix`, `nix/treefmt.nix`, `nix/devshell.nix`, `packages/zero-parades/default.nix`, and `packages/fluxer/default.nix` (Phase 5).
1. Run `treefmt --fail-on-change` (or `deadnix`, `nixf-diagnose`, `statix check`, `nixfmt --check`, `mdformat --check`), `nix flake check --no-build`, and build target checks/packages (`yijia`, `zero-parades`, `fluxer`) to verify zero evaluation, build, or formatting errors.
1. Retire (`rm` unstaged) `docs/src/plans/nix-skills-plan.md` in the same change set that completes and verifies all phases, per [`etiquette` §1](../../modules/services/ai/policies/etiquette/body.md).

## Open questions

1. **Skill identifier:** Should the skill name remain `nixos` (recommended so `/nixos` continues working unchanged while its description triggers on all Nix tasks), or should `users/home/ai-policies.nix` also expose a second alias?
   r. keep /nixos.

1. **Follow-up cleanup of existing Nix files:** Should existing repo files that exhibit findings covered by the new checklist ([`packages/zero-parades/default.nix`](../../packages/zero-parades/default.nix), [`packages/fluxer/default.nix`](../../packages/fluxer/default.nix), [`nix/devshell.nix`](../../nix/devshell.nix), [`nix/treefmt.nix`](../../nix/treefmt.nix), and `self.packages.x86_64-linux` in [`flake.nix`](../../flake.nix)) remain untouched during the policy rollout and be addressed in a separate change set?
   r. fix all.
