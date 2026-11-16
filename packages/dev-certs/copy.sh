#!/usr/bin/env bash
set -euo pipefail

src=/persist/keys/dev
dest=${1:-.}
dest=${dest%/}

if (($# > 1)); then
  echo "Usage: dev-certs-copy [folder]" >&2
  exit 1
fi

for f in ca.pem cert.pem key.pem; do
  if [[ ! -r $src/$f ]]; then
    echo "dev-certs-copy: unreadable $src/$f (key.pem needs group devcert)" >&2
    exit 1
  fi
done

if [[ -e $dest/localhost.pem || -e $dest/localhost-key.pem || -e $dest/ca.pem ]]; then
  read -rp "dev-certs-copy: overwrite files in $dest/? [y/N] " a || a=
  if [[ $a != [yY] && $a != [yY][eE][sS] ]]; then
    echo "dev-certs-copy: aborted" >&2
    exit 1
  fi
fi

if [[ ! -d $dest ]]; then
  install -d -m 0755 "$dest"
fi

install -m 0644 "$src/cert.pem" "$dest/localhost.pem"
install -m 0600 "$src/key.pem" "$dest/localhost-key.pem"
install -m 0644 "$src/ca.pem" "$dest/ca.pem"

if [[ ! -f .gitignore ]]; then
  echo "dev-certs-copy: no .gitignore here; do not commit $dest/" >&2
  exit 0
fi

if [[ -s .gitignore && -n $(tail -c 1 .gitignore) ]]; then
  printf '\n' >>.gitignore
fi

if [[ $dest == . ]]; then
  ign=(localhost.pem localhost-key.pem ca.pem)
else
  ign=("$dest/")
fi

for e in "${ign[@]}"; do
  grep -qxF "$e" .gitignore || printf '%s\n' "$e" >>.gitignore
done
