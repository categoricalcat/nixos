#! /usr/bin/env bash

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Must be run as root: su - && nix-sanity" >&2
  exit 1
fi

if [ ! -f "flake.nix" ] && [ -f "/home/yi/the.files/nixos/flake.nix" ]; then
  cd /home/yi/the.files/nixos
fi

if [ ! -f "flake.nix" ]; then
  echo "flake.nix not found" >&2
  exit 1
fi

as_yi() {
  runuser -u yi -- env HOME=/home/yi "$@"
}

quiet=false
action="build"
check=true

for arg in "$@"; do
  case "$arg" in
  --quiet) quiet=true ;;
  --no-check | -nc) check=false ;;
  switch) action="switch" ;;
  *)
    echo "Unknown argument: $arg" >&2
    exit 1
    ;;
  esac
done

if "$quiet"; then
  check_flags=()
  rebuild_flags=()
else
  check_flags=(-v)
  rebuild_flags=(-L -t -v)
fi

HOST_NAME=${HOST:-$(hostname)}

as_yi nix fmt
as_yi statix check .
as_yi deadnix --fail .
./users/scripts/setup-sops.sh
as_yi git add .
if "$check"; then
  as_yi nix flake check "${check_flags[@]}"
fi

nh os "$action" -H "$HOST_NAME" "${rebuild_flags[@]}" .
