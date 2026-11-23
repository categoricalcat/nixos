# Nix and NixOS Skill

Apply these domain rules whenever authoring, refactoring, or reviewing Nix expressions, NixOS/Home Manager modules, packages, overlays, or flakes.

## 1. Host and mesh context

- Verify which host the workspace is running on once at the start of a session when unknown (`hostname`), without re-running `hostname` before subsequent commands.
- Host configurations live under `hosts/<hostname>/configuration.nix`. Ensure evaluations, builds, and service inspections target the intended host; when editing a different host's configuration, state the target host explicitly.
- For cross-host read-only inspection (systemd units, journals, runtime state), invoke `ai-ssh <host> <command>` directly without running a local `hostname` check first.

## 2. Local inputs first (`/etc/nix/inputs`), authoritative fallback second

- Always search and read `/etc/nix/inputs` (`nixpkgs`, `home-manager`, `stylix`, `sops-nix`, `flake-parts`, `treefmt-nix`, etc.) before searching online—it holds the exact locked source trees active on the system.
- Read native `nixpkgs` library and builder APIs first—check `/etc/nix/inputs/nixpkgs/lib/default.nix` (plus `attrsets.nix`, `lists.nix`, `strings.nix`, `modules.nix`, `options.nix`, `generators.nix`, `cli.nix`, `fileset/`), `/etc/nix/inputs/nixpkgs/pkgs/pkgs-lib/formats.nix`, `/etc/nix/inputs/nixpkgs/pkgs/build-support/trivial-builders/default.nix`, and sibling modules in `/etc/nix/inputs/nixpkgs/nixos/modules/` before writing custom Nix helpers, aliasing/wrapping option schemas, or invoking external format/merge CLIs (`yq`, `jq`, `sed`) in `runCommand`.
- Never guess option names, option types, module internals, or builder arguments; verify them in source.
- When `/etc/nix/inputs` does not answer the question, consult primary upstream references: [nix.dev Best Practices](https://nix.dev/guides/best-practices), [nix.dev Module System](https://nix.dev/tutorials/module-system), [NixOS Manual — Writing Modules](https://nixos.org/manual/nixos/stable/#sec-writing-modules), [Nixpkgs Manual — Coding Conventions](https://nixos.org/manual/nixpkgs/stable/#chap-conventions), RFC 42 (`settings` / `pkgs.formats`), RFC 45 (quoted URLs), RFC 140 (`pkgs/by-name`), RFC 145 (`nixdoc`), RFC 166 (`nixfmt`), [flake.parts](https://flake.parts/module-arguments.html), and [Noogle](https://noogle.dev/).

## 3. Functional combinators and `code-quality` in Nix

- **Attribute sets:** Stay in the `AttrSet` monoid with native `lib` helpers (`lib.concatMapAttrs`, `lib.genAttrs`, `lib.mapAttrs'`, `lib.mapAttrsRecursive`, `lib.mergeAttrsList`, `lib.attrByPath`, `lib.findFirst`, `lib.pipe`). Chaining `listToAttrs`, `concatMap`, and `mapAttrsToList` through intermediate `{ name = ...; value = ...; }` pairs—or building intermediate wrapper attrsets only to unpack them one line later—is representation bouncing.
- **Products and lists:** Combine independent domains (`A × B`) applicatively with `lib.cartesianProduct` instead of nested list mappings; prefer `lib.concatMap` over `concatLists (map ...)`.
- **Nix calibration for `code-quality`:**
  - Nested attribute paths (`services.foo.settings.bar = ...`) are structural data, not control-flow nesting. Module conditionals must use lazy `lib.mkIf` and `lib.mkMerge` rather than strict `if/else` on `config`.
  - `let cfg = config.services.<name>; in` is idiomatic when `cfg` has 2+ consumers; inline single-use `let` bindings, and use `stdenv.mkDerivation (finalAttrs: ...)` instead of single-use `pname`/`version` bindings.
  - `packages/<name>/default.nix`, `hosts/<host>/`, and `modules/services/ai/policies/<name>/body.md` are convention entrypoints exempted from the single-file folder rule.

## 4. Core Nix invariants

- **Scoping:** Never introduce `rec { ... }` (use `let ... in` or `finalAttrs:`). Never place `with` at file/module top level or chain/nest `with` scopes; prefer `inherit (pkgs) ...;` or explicit `pkgs.<name>`.
- **Purity and store copies:** Never use `<nixpkgs>` lookup paths or unquoted URLs (RFC 45). Never interpolate local paths into strings (`"${./dir}"`, `import "${./file}"`, or `lib.escapeShellArg ./path`) unless copying that path into `/nix/store` at evaluation time is intended; use literal paths for `import`, `dir + "/subpath"` or `toString ./path` for path strings, and `lib.fileset.toSource` (or `dontUnpack = true`) for local package sources.
- **Store secret hygiene:** Anything interpolated into a Nix string or read via `builtins.readFile` lands world-readable (`0444`) in `/nix/store`. Bind `config.sops.secrets.<name>.path` at runtime via systemd `LoadCredential` / `EnvironmentFile` or service-native file directives.
- **Module laziness and merging:** Keep `imports` static (never conditioned on `config`), never combine `lib.mkIf` blocks with shallow `//` (use `lib.mkMerge`), and avoid Import From Derivation (IFD).
- **Executables and shell-in-Nix:** Prefer `lib.getExe` / `lib.getExe'` over `"${pkg}/bin/..."`, and prefer `pkgs.writeShellApplication` (or standalone `.sh` files checked by `treefmt`) over `pkgs.writeShellScriptBin` or unchecked inline bash heredocs.

## 5. Route the task

- **Author or refactor NixOS, Home Manager, or `flake-parts` modules:** read [references/module-patterns.md](references/module-patterns.md).
- **Author or update packages, overlays, or embedded shell scripts:** read [references/packaging-and-shell.md](references/packaging-and-shell.md).
- **Review Nix diffs, audit anti-patterns, or verify changes:** read [references/review-checklist.md](references/review-checklist.md).
