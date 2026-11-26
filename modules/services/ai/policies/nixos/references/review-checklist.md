# Nix Review Checklist and Evidence Ladder

Use this reference when auditing Nix diffs, reviewing modules/packages/overlays, or verifying changes before hand-off.

## Pass 1 — Automated static and formatting checks

1. **Unified formatter and linter gate:**
   - Run `nix fmt -- --fail-on-change` (or `treefmt --fail-on-change` inside `nix develop`) to enforce `deadnix`, `nixf-diagnose`, `statix`, `nixfmt` (RFC 166), `shfmt`, `shellcheck`, `shellharden`, and `mdformat`.
   - When checking specific Nix files directly, run `deadnix <files>`, `nixf-diagnose <files>`, `statix check <file-or-dir>`, and `nixfmt --check <files>`.
1. **Standalone shell scripts:**
   - For any `.sh` file added or modified alongside Nix expressions, verify `shellcheck <files>`, `shfmt -d -i 2 <files>`, and `shellharden --check <files>`.
1. **Custom package linting (`nixpkgs-hammer`):**
   - For derivations under `packages/*`, run `nixpkgs-hammer` when applicable. Because `nixpkgs-hammer` canonicalizes its `-f` path (rejecting `/dev/fd/*` process substitution) and expects a file accepting `{ overlays ? [], ... }:`, write the wrapper expression to the session scratch file in `/tmp/ai/`:

```bash
cat <<EOF > /tmp/ai/<session-id>.nix
{ overlays ? [ ] }:
(import /etc/nix/inputs/nixpkgs { inherit overlays; }).extend (
  _: prev: { target = prev.callPackage $PWD/packages/<name> { }; }
)
EOF
nixpkgs-hammer -f /tmp/ai/<session-id>.nix target
```

## Pass 2 — Semantic and architectural checklist

- **Laziness and recursion:**
  - Are all `imports` lists static (never gated on `config`)?
  - Do module conditionals use `lib.mkIf` and `lib.mkMerge` rather than strict `if/else` on `config` or shallow `//` between `mkIf` blocks?
  - Are `specialArgs` / `extraSpecialArgs` restricted to static flake inputs (`inputs`, `global`) with zero `config` references?
  - Is evaluation free of Import From Derivation (IFD)?
- **Scoping and merging:**
  - Any `rec { ... }` that should be `let ... in` or `finalAttrs:`?
  - Any file-level, escaping, or nested `with` (`with lib;`, `with pkgs;`, `with python3.pkgs;`) that should use `inherit (pkgs) ...;` or explicit attribute access?
  - Any shallow `//` clobbering nested attribute sets where module merging or `lib.recursiveUpdate` is intended?
  - Does every `lib.mkForce` carry a comment explaining why normal priority (`100`) or `lib.mkDefault` (`1000`) cannot be used?
- **Store copies and secret hygiene:**
  - Any unintended path interpolation (`"${./dir}"`, `import "${./file}"`, or `lib.escapeShellArg ./path`) copying local trees into `/nix/store` at evaluation time?
  - Any local package using raw `src = ./.;` or `lib.cleanSource` instead of `lib.fileset.toSource` or `dontUnpack = true`?
  - Any secret value or `builtins.readFile` secret material leaked into `/nix/store` strings or `systemd.services.<name>.environment` instead of runtime `config.sops.secrets.<name>.path` via `LoadCredential` / `EnvironmentFile`?
- **Packaging, overlays, and `strictDeps`:**
  - Does `mkDerivation` / `buildPythonPackage` use `finalAttrs:` when self-referencing, set `strictDeps = true;`, and separate `nativeBuildInputs` from `buildInputs`?
  - Under `strictDeps = true`, are script runtime interpreters (such as `bash` for `#!/usr/bin/env bash` scripts patched by `patchShebangsAuto --host`) present in `buildInputs`?
  - Do custom phases invoke `runHook pre*` and `runHook post*`, and are manual `patchShebangs` calls placed only after `chmod +x` (or omitted in favor of `fixupPhase`)?
  - Do fetchers use SRI `hash = "sha256-..."` rather than legacy hex `sha256`?
  - Do overlays modify `prev.<pkg>` (never `final.<pkg>`), pull dependencies intentionally from `final` vs `prev`, and cite the upstream issue/PR justifying the override?
- **Shell-in-Nix and executables:**
  - Are binaries referenced with `lib.getExe` / `lib.getExe'` instead of `"${pkg}/bin/..."`?
  - Are wrapper scripts built with `pkgs.writeShellApplication` (or standalone `.sh` files) rather than unchecked `pkgs.writeShellScriptBin` or raw heredocs?
  - In remaining inline shell blocks, are shell expansions quoted (`"$var"`) and Nix strings escaped (`lib.escapeShellArg`)?
- **Combinators and `flake-parts`:**
  - Do attribute-set transformations stay in the `AttrSet` monoid (`lib.concatMapAttrs`, `lib.genAttrs`, `lib.mapAttrs'`, `lib.mapAttrsRecursive`, `lib.mergeAttrsList`, `lib.findFirst`, `lib.cartesianProduct`) without `mapAttrsToList` -> `listToAttrs` representation bouncing, single-consumer `let`/alias chains, or wrapper attrsets built just to unpack fields later?
  - Do RFC 42 `settings`/`config` options use `pkgs.formats.<fmt>.type` + `lib.mapAttrsRecursive (_: lib.mkDefault)` instead of mirroring upstream leaf keys in large nested `lib.types.submodule` schemas or invoking external `yq`/`jq`/`sed` config mergers in `runCommand`?
  - Are custom helpers checked against `/etc/nix/inputs/nixpkgs/lib` and `pkgs/build-support/trivial-builders` instead of reimplementing native `nixpkgs` utilities?
  - Inside `perSystem`, are local outputs referenced via `config.packages` / `self'` rather than hardcoded `self.packages.x86_64-linux`?

## Pass 3 — Nix evidence ladder

Always state the exact verification commands executed, their outcomes, and the highest evidence level reached—never claim a change is "verified" without naming the boundary left untested.

| Evidence level          | Commands to run                                                                                                                                    | What it establishes                                                           | What remains unverified                                               |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| **Generated**           | *(none)*                                                                                                                                           | An edit was proposed                                                          | Syntax, formatting, evaluation, build, and runtime behavior           |
| **Linted & formatted**  | `nix fmt -- --fail-on-change` (or `deadnix`, `nixf-diagnose`, `statix check`, `nixfmt --check`)                                                    | Valid syntax, RFC 166 formatting, no dead bindings or local AST anti-patterns | Module evaluation, option types, derivation builds, runtime behavior  |
| **Evaluated**           | `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`; `nix flake check --no-build` only for large or cross-cutting changes | Module fixpoint converges, option types and `assertions` pass, no IFD/cycles  | Derivation compilation, `writeShellApplication` `shellcheck`, runtime |
| **Built**               | `nix build --no-link <flakeref>` or `nixos-rebuild build --flake .#<host>`                                                                         | Derivations compile, patch/fixup hooks and build-time `shellcheck` succeed    | Live systemd service startup, networking, hardware/GPU state          |
| **VM / runtime-tested** | `nix build --no-link .#checks.x86_64-linux.<test>` (`pkgs.testers.runNixOSTest`)                                                                   | Multi-unit systemd and network behavior inside a QEMU NixOS VM                | Physical host hardware, target secret decryption, external mesh       |
