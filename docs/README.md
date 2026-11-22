# Documentation

This directory contains the maintained mdBook documentation (with Mermaid support) for this NixOS gang.

## Building and Refreshing Generated Fragments

Both CI (`nix/checks.nix`) and the live `docs.aset.love` service (`docs/service.nix`) build the book through the shared `docs/builder.nix` (`docs/build.sh`) wrapper:

```sh
nix build .#checks.x86_64-linux.docs --out-link docs/book
```

Registry-derived tables under `docs/src/generated/` are rendered by `docs/generate.nix` and guarded against drift by `.#checks.x86_64-linux.docs-registry-sync`. After editing the registry (`modules/addresses/*.nix`) or exporter defaults, refresh them with:

```sh
nix build .#docs-generated --out-link /tmp/docs-frag
install -m 0644 /tmp/docs-frag/*.md docs/src/generated/
```

Use the Nix modules as source of truth when changing these docs. Planning artifacts and one-off debugging transcripts should be condensed into durable runbooks before they are committed here.
