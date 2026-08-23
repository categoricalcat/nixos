#! /usr/bin/env bash

set -euo pipefail

target="$HOME/github-backup"
quiet=false

for arg in "$@"; do
  case "$arg" in
  --quiet) quiet=true ;;
  --target=*) target="${arg#*=}" ;;
  --help)
    echo "Usage: $(basename "$0") [--quiet] [--target=<dir>]"
    echo "Clone or update all GitHub repos of the authenticated user."
    exit 0
    ;;
  *)
    echo "Unknown argument: $arg" >&2
    exit 1
    ;;
  esac
done

if ! command -v gh &>/dev/null; then
  echo "gh is not installed" >&2
  exit 1
fi

gh auth status -t &>/dev/null || {
  echo "Not authenticated with GitHub. Run: gh auth login" >&2
  exit 1
}

mkdir -p "$target"

gh repo list --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' |
  while read -r fullName; do
    [ "$fullName" = "" ] && continue
    repo="${fullName#*/}"

    if [ -d "$target/$repo" ]; then
      "$quiet" || echo "Update: $repo" >&2
      git -C "$target/$repo" fetch --all --prune --tags >/dev/null 2>&1 || {
        echo "Fetch failed: $repo" >&2
        continue
      }
      git -C "$target/$repo" reset --hard origin/HEAD >/dev/null 2>&1 || {
        echo "Reset failed: $repo" >&2
        continue
      }
    else
      "$quiet" || echo "Clone:  $repo" >&2
      gh repo clone "$fullName" "$target/$repo" "${quiet:+-- --quiet}" || {
        echo "Clone failed: $repo" >&2
        continue
      }
    fi
  done
