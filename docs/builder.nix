# Shared docs builder: one definition consumed by the docs service
# (docs/service.nix, live bind mount) and the CI check (nix/checks.nix,
# flake source).
{ pkgs }:
pkgs.writeShellApplication {
  name = "build-gang-docs";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gnused
    pkgs.findutils
    pkgs.mdbook
    pkgs.mdbook-mermaid
    pkgs.rsync
  ];
  text = builtins.readFile ./build.sh;
}
