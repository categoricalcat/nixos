#!/usr/bin/env bash
# Derive age identity from an SSH private key using ssh-to-age.

derive_age_key() {
  local priv="$1"
  local out="$2"
  local owner_group="$3"
  local out_dir
  out_dir="$(dirname "$out")"

  mkdir -p "$out_dir"
  chown "$owner_group" "$out_dir"
  local cmd=(ssh-to-age)
  if ! command -v ssh-to-age >/dev/null 2>&1; then
    cmd=(nix shell "nixpkgs#ssh-to-age" -c ssh-to-age)
  fi
  # shellcheck disable=SC2024
  if "${cmd[@]}" -private-key -i "$priv" >"$out"; then
    chown "$owner_group" "$out"
    chmod 0600 "$out"
  else
    rm -f "$out"
    echo "-> warning: could not derive age identity from $priv" >&2
  fi
}
