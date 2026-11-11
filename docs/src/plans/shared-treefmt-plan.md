# Shared treefmt flake module

Status: pending

## Objective

Export this repo's treefmt configuration as a reusable flake-parts module so satellite repos import it instead of copying it. Eliminates the duplicated formatter config now appearing in `mc-aset-loveland/nix/treefmt.nix`.

## Current state

- [nix/treefmt.nix](../../../nix/treefmt.nix) defines the house style: deadnix, nixf-diagnose, statix (+ mkForce wrapper), nixfmt, shfmt (indent 2), shellcheck, shellharden, mdformat
- `mc-aset-loveland` (sibling repo) copied it, minus mdformat, plus `programs.prettier`, a custom eslint formatter, and repo-specific global excludes. Two copies of the same policy now drift independently
- This repo's flake already uses flake-parts; adding a `flakeModules` export is a one-line change here

## Decisions

- Export name: `flakeModules.treefmt` (namespaced; `default` would invite blind imports)
- The shared module keeps only generic policy (nix + shell + md formatters and their priorities). Repo-specific concerns (prettier, eslint, per-repo excludes like `pnpm-lock.yaml`) stay in the consumer
- This repo imports its own exported module (dogfooding, zero behavior change): `imports = [ ./nix/treefmt.nix ]` becomes `imports = [ self.flakeModules.treefmt ]` — or simply keeps importing the file while also exporting it; same content either way

## Phases

### Phase 1 — export (this repo)

- `flake.nix`: inside `mkFlake`'s `flake` attrset add `flakeModules.treefmt = ./nix/treefmt.nix;`
- Verify: `nix flake check --no-build`, `nix fmt -- --ci` unchanged (idempotent), one host eval to confirm no module regression

### Phase 2 — consumer (mc-aset-loveland, separate PR there)

- Add `nixos` (this repo) as flake input with `inputs.nixpkgs.follows`
- Replace duplicated policy in `mc-aset-loveland/nix/treefmt.nix` with `imports = [ inputs.nixos.flakeModules.treefmt ]` plus its own `perSystem.treefmt` overlay: prettier, eslint formatter, global excludes
- Verify: `nix fmt` output identical to pre-change run on the same tree

## Rollout order

1. PR here: export only (no behavior change)
1. PR in mc-aset-loveland: consume + delete duplicated config

## Open questions

- Module arg plumbing: the current file closes over `lib` only — confirm no consumer needs `inputs` passed through (today: no)
- mdformat vs prettier on Markdown: this repo standardizes on mdformat, mc-aset-loveland on prettier. Keep both policies local (shared module ships mdformat; consumer disables via `programs.mdformat.enable = lib.mkForce false` if undesired) — or drop mdformat from the shared set?
