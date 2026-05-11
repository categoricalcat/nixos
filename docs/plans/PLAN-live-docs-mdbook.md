# Python-Free Infrastructure Documentation (mdBook & Nixpkgs)

## Background & Motivation

The user wants a formal, "live" documentation portal for their NixOS infrastructure. To ensure security and a lightweight environment, the solution must rely exclusively on tools available in the standard `nixpkgs` collection, specifically avoiding Python and any third-party flake inputs. The documentation will include tables and diagrams (Mermaid) generated directly from the Nix source code.

## Scope & Impact

- No new flake inputs.
- Use **mdBook** (Rust-based) and **mdbook-mermaid** from `nixpkgs`.
- Use Nix evaluation to extract configuration data (IPs, services, network structure) and generate Markdown.
- Output: A static documentation site ("book") that reflects the current state of the infrastructure.

## Proposed Solution

We will implement a custom documentation pipeline using native Nix and Rust-based tools:

1. **Data Extraction (Nix)**:
    - We will write a Nix script to iterate over `self.nixosConfigurations`.
    - It will extract structural info from your hosts (e.g., `networking.interfaces`, `services`, and custom `addresses.nix` data).
    - It will format this into Markdown files (`SUMMARY.md` for navigation, plus individual host/service pages).
2. **Visuals (Mermaid)**:
    - The Nix script will generate Mermaid graph definitions (e.g., `graph TD`) describing the network topology and host relationships.
    - `mdbook-mermaid` will render these into visual diagrams.
3. **Build Pipeline**:
    - A Nix derivation (`packages.<system>.docs`) will provide the `mdbook` and `mdbook-mermaid` binaries.
    - It will run the data extraction script to populate a source directory.
    - It will run `mdbook build` to produce the final static HTML site.

## Implementation Steps

### Phase 1: Exploration & Data Mapping

1. Identify the specific Nix attributes across the hosts that provide the "truth" for networking and services.
2. Confirm the exact package names for `mdbook` and its Mermaid plugin in your current `nixpkgs`.

### Phase 2: The Nix Generator

1. Create a `lib/docs-generator.nix` that transforms the host configurations into a set of Markdown files and a `book.toml`.
2. Implement the logic to generate Mermaid diagrams from the detected network structure.

### Phase 3: Integration

1. Add the `docs` package to your `flake.nix`.
2. Create a development shell entry to allow running `mdbook serve` for live documentation previews while editing.

## Verification

- Build the docs via `nix build .#docs`.
- Inspect the generated Markdown to ensure tables accurately reflect the Nix configuration.
- Verify that Mermaid diagrams render correctly in the final HTML book.
