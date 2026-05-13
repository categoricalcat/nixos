# Documentation

This directory contains the maintained documentation for this NixOS fleet.

The source is an mdBook:

```sh
nix shell nixpkgs#mdbook -c mdbook build docs
nix shell nixpkgs#mdbook -c mdbook serve docs
```

The generated book is written to `docs/book/`.

Use the Nix modules as source of truth when changing these docs. Planning
artifacts and one-off debugging transcripts should be condensed into durable
runbooks before they are committed here.
