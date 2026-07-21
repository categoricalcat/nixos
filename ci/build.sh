#!/usr/bin/env bash
set -euo pipefail

BUILDER_ARGS=()
if timeout 2 bash -c '</dev/tcp/yitaishi.ts/24212' 2>/dev/null || timeout 2 bash -c '</dev/tcp/yitaishi.nb/24212' 2>/dev/null; then
  echo "yitaishi is online! Adding as a remote builder."
  b="ssh-ng://yitaishi x86_64-linux - 16 100 kvm,nixos-test,benchmark,big-parallel"
  [ -f /etc/nix/machines ] && b="@/etc/nix/machines ; $b"
  BUILDER_ARGS=(--builders "$b")
else
  echo "yitaishi is offline. Proceeding without it."
fi

host="$1"
echo "::group::nix build $host"
nix build --refresh "${BUILDER_ARGS[@]}" --print-build-logs ".#nixosConfigurations.$host.config.system.build.toplevel" --out-link "result-$host"
echo "::endgroup::"
