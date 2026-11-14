# Nixpkgs Packaging, Overlays, and Shell-in-Nix

Use this reference when writing or updating packages, Python/language derivations, overlays, or shell scripts embedded in Nix.

## Derivation structure (`callPackage` and `finalAttrs`)

- Accept only required dependencies in the `callPackage` function header (`{ lib, stdenv, fetchFromGitHub, ... }:`). Never accept the entire `pkgs` set unless writing a package set or wrapper table.
- Use the fixed-point `finalAttrs:` form instead of `rec { ... }` whenever attributes self-reference (`version`, `src`, `pname`), including in `python3.pkgs.buildPythonPackage (finalAttrs: { ... })`, so `.overrideAttrs` propagates updates cleanly:

```nix
stdenv.mkDerivation (finalAttrs: {
  pname = "example";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "example";
    repo = "example";
    tag = "v${finalAttrs.version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  strictDeps = true;
})
```

- Set `strictDeps = true;` on `stdenv.mkDerivation` to enforce build/host dependency separation:
  - `nativeBuildInputs`: build-time tools executed on the build machine (`pkg-config`, compilers, `makeWrapper`, `copyDesktopItems`, `autoPatchelfHook`).
  - `buildInputs`: target libraries linked or interpreted on the host (`openssl`, `alsa-lib`, and `bash` when installed scripts have `#!/usr/bin/env bash` rewritten by `patchShebangsAuto --host` under `strictDeps = true`).
- For PEP-621 Python packages (`pyproject = true` or `format = "wheel"`), declare build backends in `build-system` and runtime libraries in `dependencies` using explicit `python3.pkgs.<name>` references rather than `with python3.pkgs;`.

## Sources, fetchers, and `lib.fileset`

- Always specify SRI hashes (`hash = "sha256-..."`); never use legacy hex `sha256 = "..."` or placeholder hashes without verifying the fixed-output build.
- Never set `src = ./.;` on a directory containing `default.nix`, READMEs, or build artifacts—any edit to `default.nix` changes the source store hash and forces an unnecessary rebuild while copying unrelated files into `/nix/store`.
  - When building from a subset of local files, use `lib.fileset.toSource`:

```nix
src = lib.fileset.toSource {
  root = ./.;
  fileset = lib.fileset.unions [
    ./Cargo.toml
    ./Cargo.lock
    ./src
  ];
};
```

- When `installPhase` only substitutes or copies explicit local files (`${./launcher.sh}`, `${./icon.png}`), omit `src` and set `dontUnpack = true;`.

## Executables, phases, and `meta`

- Reference package executables with `lib.getExe pkg` (requires `meta.mainProgram`) or `lib.getExe' pkg "bin-name"` rather than `"${pkg}/bin/..."`.
- Every custom `buildPhase`, `checkPhase`, or `installPhase` must begin with `runHook pre<Phase>` and end with `runHook post<Phase>` so setup hooks (`copyDesktopItems`, `wrapPythonPrograms`, `autoPatchelfHook`) execute.
- `patchShebangs` ignores non-executable files (`find ... -perm -0100`). Never run `patchShebangs` before `chmod +x`; prefer letting `fixupPhase`'s `patchShebangsAuto` rewrite executable scripts automatically (with the interpreter package in `buildInputs` when `strictDeps = true`).
- Populate `meta` (`description`, `homepage`, `license` via `lib.licenses.*`, `platforms` via `lib.platforms.*`, and `mainProgram`) without `with lib;`.
- Document reusable `lib` helper functions with **RFC 145** `/** ... */` doc-comments.

## Overlays (`final: prev:`)

- **Modifying an existing package:** Always invoke `prev.<pkg>.override` or `prev.<pkg>.overrideAttrs`—referencing `final.<pkg>` in its own definition causes infinite recursion.
- **Selecting dependencies:** Pull dependencies and `callPackage` from `final` (`final.callPackage`, `final.<dep>`) when overrides should propagate through the overlay fixpoint, or from `prev` when intentionally isolating a standalone build.
- **Document retirement conditions:** Every overlay patch, test skip, or build workaround must include a comment explaining *why* it is needed and citing the upstream issue or PR so stale overrides can be removed on `flake.lock` updates.

## Shell-in-Nix hygiene

- `nix/treefmt.nix` runs `shellcheck`, `shfmt`, and `shellharden` only on `.sh` files—inline Nix multiline strings (`'' ... ''`) bypass `treefmt`'s shell linters.
- Prefer `pkgs.writeShellApplication` over `pkgs.writeShellScriptBin` or raw `cat << 'EOF'` heredocs:

```nix
pkgs.writeShellApplication {
  name = "sync-example";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.jq
  ];
  text = builtins.readFile ./sync-example.sh;
}
```

`writeShellApplication` sets `set -euo pipefail`, prepends `runtimeInputs` to `PATH`, sets `meta.mainProgram`, and runs `shellcheck` during `checkPhase`.

- For non-trivial scripts (>15 lines), keep the body in a standalone `.sh` file (`text = builtins.readFile ./script.sh;`) so `treefmt` enforces `shfmt`, `shellcheck`, and `shellharden` alongside build-time checks. Note that `writeShellApplication` prepends its own shebang and `set -euo pipefail`; standalone `.sh` files loaded via `builtins.readFile` can keep `#!/usr/bin/env bash` and `set -euo pipefail` safely (the inner shebang becomes a comment line).
- In inline `systemd.services.<name>.script` or build phases:
  - Double-quote all shell variable expansions (`"$var"`, `"$@"`), escaping Nix's `''${var}` interpolation prefix carefully.
  - Escape Nix strings interpolated into shell commands with `lib.escapeShellArg` / `lib.escapeShellArgs`.
  - Never pass a raw Nix path literal (`./dir`) directly to `lib.escapeShellArg` unless copying that path into `/nix/store` is intended (`escapeShellArg` coerces paths via `"${x}"`); apply `toString` first for local filesystem paths.
