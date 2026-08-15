#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: ai-ssh <host> <command...>" >&2
  exit 1
fi

host=$1
shift

# The destination must be a bare host, never an ssh option: otherwise a caller
# could smuggle -o ProxyCommand=... (runs locally, before any server gate).
case "$host" in
  -*) echo "ai-ssh: refusing option-like host: $host" >&2; exit 1 ;;
esac

# Encode argv so the server gate reconstructs it exactly (spaces/quotes intact,
# no eval). Protocol: literal "v1" then one base64 token per argument.
enc="v1"
for a in "$@"; do
  enc+=" $(printf '%s' "$a" | base64 -w0)"
done

exec ssh -l ai -i ~/.ssh/id_ai_ed25519 \
  -o IdentitiesOnly=yes \
  -o BatchMode=yes \
  -o ConnectTimeout=5 \
  -o StrictHostKeyChecking=yes \
  -- "$host" "$enc"
