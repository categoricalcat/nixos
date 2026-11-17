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
-*)
  echo "ai-ssh: refusing option-like host: $host" >&2
  exit 1
  ;;
esac

# If passed as a single quoted string (e.g. ai-ssh host "cmd arg1 arg2"),
# split it into positional arguments so the server gate receives individual
# tokens. read, not eval: eval would execute shell metacharacters (;, |, $(),
# globs) locally on the calling host before any server-side gate sees them.
# Word-splitting only; pass multiple arguments when quoting must survive.
if [ "$#" -eq 1 ]; then
  read -r -a argv <<<"$1" || true
  set -- "${argv[@]}"
fi

# Encode argv so the server gate reconstructs it exactly (spaces/quotes intact,
# no eval). Protocol: literal "v1" then one base64 token per argument.
enc="v1"
for a in "$@"; do
  enc+=" $(printf '%s' "$a" | base64 -w0)"
done

exec ssh -T -l ai -i ~/.ssh/id_ai_ed25519 \
  -o IdentitiesOnly=yes \
  -o BatchMode=yes \
  -o ConnectTimeout=5 \
  -o StrictHostKeyChecking=yes \
  -- "$host" "$enc"
