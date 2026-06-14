#! /usr/bin/env bash

set -euo pipefail

if [ ! -f "flake.nix" ]; then
  echo "flake.nix not found" >&2
  exit 1
fi

quiet=false
action="build"

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
  rebuild_flags=(-L -t -v)
fi

HOST_NAME=${HOST:-$(hostname)}

sudo nix fmt
statix check .
deadnix -- --fail .
./users/scripts/setup-sops.sh
git add .
nix flake check "${check_flags[@]}"
nh os "$action" -H "$HOST_NAME" "${rebuild_flags[@]}" .
