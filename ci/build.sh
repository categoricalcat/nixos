#!/usr/bin/env bash
set -euo pipefail

BUILDER_ARGS=()
if timeout 2 bash -c '</dev/tcp/yitaishi.ts/24212' 2>/dev/null || timeout 2 bash -c '</dev/tcp/yitaishi.nb/24212' 2>/dev/null; then
  echo "yitaishi is online! Adding as a remote builder."
  b="ssh-ng://yitaishi x86_64-linux - 16 100 kvm,nixos-test,benchmark,big-parallel"
  [ -f /etc/nix/machines ] && b="@/etc/nix/machines ; $b"
  BUILDER_ARGS=(--option builders "$b")
else
  echo "yitaishi is offline. Proceeding without it."
fi

attic login "$ATTIC_CACHE_NAME" "$ATTIC_INTERNAL_URL" "${ATTIC_TOKEN:?attic token is empty}"
nix run --inputs-from . nixpkgs#lixPackageSets.lix_2_96.nix-fast-build -- "${BUILDER_ARGS[@]}" --flake .#hydraJobs --skip-cached --retries 1 --eval-workers 2 --attic-cache "$ATTIC_CACHE_NAME:$ATTIC_CACHE_NAME" --attic-ignore-upstream-cache-filter
