#!/usr/bin/env bash
# Build the gang docs book: copy <src> to a tmpdir, append src/plans/*.md to
# SUMMARY.md, run mdbook-mermaid + mdbook, rsync the book into <out>.
# One script serves the docs service (live bind mount, docs/service.nix) and
# the CI check (flake source, nix/checks.nix), so every commit proves the
# production build path.
# usage: build.sh <src-dir> <out-dir>
set -euo pipefail

src=$1
out=$2
tmp=$(mktemp -d)
trap 'rm -rf "${tmp:?}"' EXIT

cp -r "$src"/. "$tmp/"
chmod -R u+w "$tmp"
rm -rf "$tmp/book" "$tmp/.git"

printf '\n# Architecture Plans & RFCs\n\n- [Architecture Plans]()\n' >>"$tmp/src/SUMMARY.md"
for p in "$tmp"/src/plans/*.md; do
  [ -f "$p" ] || continue
  case "$(basename "$p")" in .* | *~ | *.tmp | *.bak | '#*' | _*) continue ;; esac
  t=$(sed -n 's/^# //p; T; q' "$p" | tr -d '\r' | sed 's/\[/\\[/g; s/\]/\\]/g' | xargs)
  echo "  - [${t:-$(basename "$p" .md)}](plans/$(basename "$p"))" >>"$tmp/src/SUMMARY.md"
done

mdbook-mermaid install "$tmp"
mdbook build "$tmp" -d "$tmp/book" >/dev/null

mkdir -p "$out"
rsync -r --delete --no-owner --no-group "$tmp/book/" "$out/"
