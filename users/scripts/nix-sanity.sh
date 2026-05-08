#! /usr/bin/env bash

set -euo pipefail

if [ ! -f "flake.nix" ]; then
  echo "flake.nix not found" >&2
  exit 1
fi

quiet=false
action="dry-build"

for arg in "$@"; do
  case "$arg" in
    --quiet) quiet=true ;;
    switch)  action="switch" ;;
    *)       echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if $quiet; then
  check_flags=()
  rebuild_flags=()
else
  check_flags=(-v)
  rebuild_flags=(--print-build-logs --show-trace)
fi

sudo nix fmt
git add .
nix flake check "${check_flags[@]}"
sudo nixos-rebuild --flake ".#$(hostname)" --upgrade "${rebuild_flags[@]}" "$action"
