#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <gate|dry|switch|boot|dry-activate|diff|deploy|1-diff|2-deploy> <host>" >&2
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

gate() {
  local target="$1" new_system
  new_system=$(nix eval --raw ".#nixosConfigurations.$target.config.system.build.toplevel")
  if ! curl -sf -o /dev/null "$ATTIC_INTERNAL_URL/$ATTIC_CACHE_NAME/$(basename "$new_system" | cut -d- -f1).narinfo"; then
    echo "::error::$new_system is not in attic; wait for CI on ${GITHUB_SHA:-HEAD}" >&2
    exit 1
  fi
}

dry_activate() {
  local target="$1"
  echo "::group::deploy dry-activate $target"
  deploy --skip-checks .#"$target" --dry-activate
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
  echo "::group::deploy switch $target"
  deploy --skip-checks .#"$target" -- --print-build-logs
  echo "::endgroup::"
}

deploy_boot() {
  local target="$1"
  echo "::group::deploy boot $target"
  deploy --skip-checks .#"$target" --boot -- --print-build-logs
  echo "::endgroup::"
}

case "$action" in
gate)
  gate "$host"
  ;;
dry | 1-diff)
  dry_activate "$host"
  diff_closure "$host"
  ;;
dry-activate | dry-run)
  dry_activate "$host"
  ;;
diff)
  diff_closure "$host"
  ;;
switch | deploy | 2-deploy | live | apply)
  deploy_live "$host"
  ;;
boot)
  deploy_boot "$host"
  ;;
*)
  echo "Unknown action: $action" >&2
  usage
  ;;
esac
