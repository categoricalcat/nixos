# Documentation

This directory contains the maintained documentation for this NixOS gang.

The source is an mdBook with native Mermaid support.

## Building and Serving

To build the HTML book into `docs/book/`:

```sh
nix-shell docs --run docs-build
```

To serve the book interactively on localhost:

```sh
nix-shell docs --run docs-serve
```

Or enter the docs environment directly:

```sh
cd docs && nix-shell
docs-build
docs-serve
```

Or build the derivation directly into the Nix store:

```sh
nix-build docs
```

The generated book is written to `docs/book/`.

Use the Nix modules as source of truth when changing these docs. Planning
artifacts and one-off debugging transcripts should be condensed into durable
runbooks before they are committed here.
