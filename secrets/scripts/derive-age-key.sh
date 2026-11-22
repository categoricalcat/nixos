#!/usr/bin/env bash
# Derive age identity from an SSH private key using ssh-to-age.
# usage: derive-age-key <ssh-private-key> <out> <owner:group>
set -euo pipefail

priv="$1"
out="$2"
owner_group="$3"
out_dir="$(dirname "$out")"

mkdir -p "$out_dir"
chown "$owner_group" "$out_dir"
if ssh-to-age -private-key -i "$priv" >"$out"; then
  chown "$owner_group" "$out"
  chmod 0600 "$out"
else
  rm -f "$out"
  echo "-> warning: could not derive age identity from $priv" >&2
fi
