#!/usr/bin/env bash
set -euo pipefail

thefiles='--override-input thefiles github:categoricalcat/the.files'

BUILDER_ARGS=()
if ping -c 1 -W 2 yitaishi.vpn >/dev/null 2>&1; then
  echo "yitaishi is online! Adding as a remote builder."
  b="ssh-ng://yitaishi x86_64-linux - 16 100 kvm,nixos-test,benchmark,big-parallel"
  [ -f /etc/nix/machines ] && b="@/etc/nix/machines ; $b"
  BUILDER_ARGS=(--builders "$b")
else
  echo "yitaishi is offline. Proceeding without it."
fi

while read -r h; do
  echo
  echo "=== Building $h ==="
  nix build --refresh $thefiles "${BUILDER_ARGS[@]}" --print-build-logs ".#nixosConfigurations.$h.config.system.build.toplevel" --out-link "result-$h"
done < .hosts
