#!/usr/bin/env bash
# Prepend the Nix theme-font block to SillyTavern's mutable user.css.
# A previous block is replaced; every other line is kept.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  printf 'usage: %s <user.css> <block.css>\n' "$0" >&2
  exit 2
fi

target="$1"
block="$2"
target_dir="$(dirname "$target")"
start='/* nix-theme:start */'
end='/* nix-theme:end */'

tmp_file=""
cleanup() {
  if [ "$tmp_file" != "" ] && [ -e "$tmp_file" ]; then
    rm -f "$tmp_file"
  fi
}
trap cleanup EXIT

install -d -m 0700 "$target_dir"
tmp_file="$(mktemp "${target_dir}/.user.css.XXXXXX")"
chmod 0600 "$tmp_file"

{
  cat "$block"
  if [ -f "$target" ]; then
    awk -v start="$start" -v end="$end" '
      $0 == start { skip = 1; next }
      $0 == end { skip = 0; next }
      skip != 1 { print }
    ' "$target"
  else
    printf '/* Put custom styles here. */\n'
  fi
} >"$tmp_file"

mv -f "$tmp_file" "$target"
tmp_file=""
