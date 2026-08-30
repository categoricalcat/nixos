#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <dry-activate|diff|deploy|1-diff|2-deploy> <host>" >&2
  exit 1
}

if [ "$#" -lt 2 ]; then
  usage
fi

action="$1"
host="$2"

SSH_KEY_ARGS=()
if [ "${SSH_KEY:-}" != "" ]; then
  SSH_KEY_ARGS=(-i "$SSH_KEY")
elif [ -f /var/lib/nix-builder/.ssh/id_ed25519 ]; then
  SSH_KEY_ARGS=(-i /var/lib/nix-builder/.ssh/id_ed25519)
fi

dry_activate() {
  local target="$1"
  echo "::group::deploy dry-activate $target"
  deploy .#"$target" --dry-activate
  echo "::endgroup::"
}

diff_closure() {
  local target="$1"
  echo "::group::diff package closures for $target"
  local target_ip new_system
  target_ip=$(nix eval --raw ".#deploy.nodes.$target.hostname")
  new_system=$(nix eval --raw ".#nixosConfigurations.$target.config.system.build.toplevel")

  ssh "${SSH_KEY_ARGS[@]}" -p 24212 -o StrictHostKeyChecking=accept-new root@"$target_ip" \
    "export PATH=\"/run/current-system/sw/bin:\$PATH\"; if command -v nvd >/dev/null 2>&1; then nvd diff /run/current-system \"$new_system\"; elif [ -x \"$new_system/sw/bin/nvd\" ]; then \"$new_system/sw/bin/nvd\" diff /run/current-system \"$new_system\"; else nix store diff-closures /run/current-system \"$new_system\"; fi"
  echo "::endgroup::"
}

deploy_live() {
  local target="$1"
  echo "::group::deploy $target"
  deploy .#"$target" -- --print-build-logs
  echo "::endgroup::"
}

case "$action" in
dry-activate | dry-run)
  dry_activate "$host"
  ;;
diff)
  diff_closure "$host"
  ;;
deploy | live | apply)
  deploy_live "$host"
  ;;
1-diff)
  dry_activate "$host"
  diff_closure "$host"
  ;;
2-deploy)
  deploy_live "$host"
  ;;
*)
  echo "Unknown action: $action" >&2
  usage
  ;;
esac
