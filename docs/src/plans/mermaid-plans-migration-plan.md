# Mermaid Plans Migration Plan

## Objective

Migrate architectural, rollout, and module hierarchy diagrams across all gang RFC plans (`docs/src/plans/*.md`) from static ASCII text blocks to interactive, themed Mermaid diagrams, supported natively by mdBook via the `mdbook-mermaid` preprocessor with zero committed JavaScript binaries (relying purely on Nix derivation and service build hooks).

______________________________________________________________________

## Current State

1. **mdBook Rendering**: mdBook renders code blocks with syntax highlighting by default. It lacks native Mermaid rendering out of the box.
1. **Assets Policy**: Committing large vendored JavaScript binaries (such as `mermaid.min.js`, ~2.6 MB) into the git repository is rejected.
1. **Nix Store Provisioning**: Nixpkgs provides `pkgs.mdbook-mermaid` (v0.17.1), which contains compiled-in Mermaid assets and can inject them dynamically into build sandboxes and ephemeral directories (`mdbook-mermaid install <dir>`).
1. **Documentation Daemon**: `modules/services/docs.nix` builds the book into an ephemeral `$tmp` directory before syncing to `/var/lib/gang-docs/book/` and serving via `darkhttpd`.
1. **Developer Shell**: `nix/devshell.nix` provides development tools and wrapper binaries (`inspect`, `host-tree`, `host-audit`).
1. **Plan Files**: All 7 active RFC plans contained ASCII box-drawing or tree structures that are harder to read and do not integrate with mdBook's dark/light theme switching.

______________________________________________________________________

## Decisions

1. **Pure Nix Asset Management**: Do not commit `mermaid.min.js` or `mermaid-init.js` to git. Ignore them in `.gitignore`.
1. **Ephemeral Build Injection & Scoped Dev Environment**:
   - In `modules/services/docs.nix`, `buildDocs` runs `mdbook-mermaid install "$tmp"` dynamically inside the temporary build directory.
   - In `docs/shell.nix` and `docs/default.nix`, provide self-contained `docs-build`, `docs-serve`, and `gang-docs` derivations scoped strictly to the `docs/` folder, keeping the root `nix/devshell.nix` clean.
1. **Clean Configuration**:
   - `docs/book.toml` declares `[preprocessor.mermaid]` with `command = "mdbook-mermaid"`.
   - `additional-js` is not committed in `docs/book.toml` so the repo does not require checked-in `.js` files; it is injected dynamically by `mdbook-mermaid install` inside `$tmp`.
1. **Universal Mermaid Standard**:
   - Flowcharts, subsystem boundaries, and phase rollouts across all plans use standard Mermaid (`flowchart TD` / `flowchart LR`).
   - Node labels containing punctuation or extra info are quoted to prevent syntax ambiguities.

______________________________________________________________________

## Architecture

````mermaid
flowchart TD
    subgraph Repo["Git Repository (the.files/nixos)"]
        BOOK_TOML["docs/book.toml<br/>([preprocessor.mermaid])"]
        PLANS["docs/src/plans/*.md<br/>(```mermaid diagrams)"]
        GITIGNORE[".gitignore<br/>(docs/mermaid*.js)"]
    end

    subgraph NixStore["Nix Store"]
        NIX_MDBOOK["pkgs.mdbook"]
        NIX_MERMAID["pkgs.mdbook-mermaid<br/>(compiled-in mermaid assets)"]
    end

    subgraph BuildRuntime["Ephemeral Build Sandbox ($tmp)"]
        INSTALL["mdbook-mermaid install $tmp<br/>(injects mermaid.min.js & init)"]
        BUILD["mdbook build $tmp"]
        HTML["Generated Book Output<br/>(SVG diagrams + theme syncing)"]
        INSTALL --> BUILD --> HTML
    end

    Repo -->|bind-mount or cp| BuildRuntime
    NixStore -->|PATH binaries| BuildRuntime
````

______________________________________________________________________

## Phases

### Phase 1: mdBook Preprocessor & Service Integration

- In `docs/book.toml`, register `[preprocessor.mermaid]` with `command = "mdbook-mermaid"`.
- In `modules/services/docs.nix`, add `pkgs.mdbook-mermaid` to `makeBinPath` and invoke `mdbook-mermaid install "$tmp"` before `mdbook build`.
- In `nix/devshell.nix`, add `mdbook` and `mdbook-mermaid` to `nixDevPkgs`, and export `docs-build` and `docs-serve` wrapper scripts.
- In `.gitignore`, ignore `docs/mermaid*.js`.
- In `docs/README.md`, document `docs-build` and `docs-serve`.

### Phase 2: Plans Migration

- Migrate `docs/src/plans/guitar-rig-plugins-plan.md` to Mermaid.
- Migrate `docs/src/plans/audio-midi-presets-plan.md` to Mermaid.
- Migrate `docs/src/plans/audio-module-fixes-plan.md` to Mermaid.
- Migrate `docs/src/plans/service-security-architecture-plan.md` to Mermaid.
- Migrate `docs/src/plans/mtls-architecture-plan.md` to Mermaid.
- Migrate `docs/src/plans/impermanence-yirukou-plan.md` to Mermaid.
- Migrate `docs/src/plans/vpn-to-lan-migration-plan.md` to Mermaid.

### Phase 3: Verification & Auditing

- Run `statix check` and `deadnix` on modified Nix modules.
- Evaluate the `yifuwuqi` system toplevel derivation to confirm clean evaluation.
- Run `docs-build` to confirm all chapters and diagrams compile cleanly into SVG without warnings.
- Audit `git diff` to guarantee zero stray files or staging area modifications.

______________________________________________________________________

## Rollout Order

1. Apply `docs/book.toml`, `modules/services/docs.nix`, `nix/devshell.nix`, `.gitignore`, and `docs/README.md`.
1. Apply diagram migrations to `docs/src/plans/*.md`.
1. Run verification checks (`docs-build`, `statix`, `nix eval`).
1. Review working tree diff for staging and committing by user.

______________________________________________________________________

## Open Questions

None. The pure Nix ephemeral asset injection completely resolves the binary vendoring dilemma while ensuring 100% offline functionality.
