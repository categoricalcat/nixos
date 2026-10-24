#!/usr/bin/env bash
set -euo pipefail

GREEN=$'\033[1;32m'
CYAN=$'\033[1;36m'
DIM=$'\033[2m'
RESET=$'\033[0m'

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

eval_toplevel() {
  nix eval --raw ".#nixosConfigurations.$1.config.system.build.toplevel"
}

eval_host_ip() {
  nix eval --raw ".#deploy.nodes.$1.hostname"
}

gate() {
  local target="$1" new_system hash
  echo "::group::Verify Attic cache for $target"
  new_system=$(eval_toplevel "$target")
  hash=$(basename "$new_system" | cut -d- -f1)
  if ! curl -sf -o /dev/null "$ATTIC_INTERNAL_URL/$ATTIC_CACHE_NAME/$hash.narinfo"; then
    echo "::endgroup::"
    echo "::error::$new_system is not in attic; wait for CI on ${GITHUB_SHA:-HEAD}" >&2
    exit 1
  fi
  printf '%s✔ Attic cache hit%s for %s%s%s (%s)\n' "$GREEN" "$RESET" "$CYAN" "$target" "$RESET" "$new_system"
  echo "::endgroup::"
}

dry_activate() {
  local target="$1"
  echo "::group::Dry-activate $target"
  deploy --skip-checks ".#$target" --dry-activate
  printf '%s✔ Dry-activation succeeded%s for %s\n' "$GREEN" "$RESET" "$target"
  echo "::endgroup::"
}

diff_closure() {
  local target="$1" target_ip new_system current_system diff_out
  echo "::group::Diff package closures for $target"
  target_ip=$(eval_host_ip "$target")
  new_system=$(eval_toplevel "$target")

  current_system=$(ssh "${SSH_KEY_ARGS[@]}" -p 24212 -o StrictHostKeyChecking=accept-new root@"$target_ip" \
    "readlink -f /run/current-system || echo unknown")

  diff_out=$(ssh "${SSH_KEY_ARGS[@]}" -p 24212 -o StrictHostKeyChecking=accept-new root@"$target_ip" \
    "export PATH=\"/run/current-system/sw/bin:\$PATH\"; if command -v nvd >/dev/null 2>&1; then nvd diff /run/current-system \"$new_system\"; elif [ -x \"$new_system/sw/bin/nvd\" ]; then \"$new_system/sw/bin/nvd\" diff /run/current-system \"$new_system\"; else nix store diff-closures /run/current-system \"$new_system\"; fi")

  printf '%s\n' "$diff_out"
  echo "::endgroup::"

  if [ "${GITHUB_STEP_SUMMARY:-}" != "" ]; then
    {
      printf '## Deployment Preflight: \140%s\140\n\n' "$target"
      printf '| Field | Value |\n| :--- | :--- |\n'
      printf '| **Host** | \140%s\140 (\140%s\140) |\n' "$target" "$target_ip"
      printf '| **Current System** | \140%s\140 |\n' "$current_system"
      printf '| **Target System** | \140%s\140 |\n' "$new_system"
      printf '| **Attic Cache** | Verified in \140%s\140 |\n\n' "${ATTIC_CACHE_NAME:-yi}"
      printf '### Package Closure Diff (\140nvd\140)\n\n~~~text\n%s\n~~~\n\n' "$diff_out"
    } >>"$GITHUB_STEP_SUMMARY"
  fi
}

deploy_live() {
  local target="$1" new_system
  echo "::group::Deploy switch $target"
  new_system=$(eval_toplevel "$target")
  deploy --skip-checks ".#$target" -- --print-build-logs
  printf '%s✔ Live activation complete%s for %s (%s)\n' "$GREEN" "$RESET" "$target" "$new_system"
  echo "::endgroup::"

  if [ "${GITHUB_STEP_SUMMARY:-}" != "" ]; then
    {
      printf '## Live Activation: \140%s\140\n\n' "$target"
      printf -- '- **Action**: \140switch\140 (with magic rollback)\n'
      printf -- '- **Activated System**: \140%s\140\n' "$new_system"
      printf -- '- **Status**: Succeeded\n\n'
    } >>"$GITHUB_STEP_SUMMARY"
  fi
}

deploy_boot() {
  local target="$1" new_system
  echo "::group::Deploy boot $target"
  new_system=$(eval_toplevel "$target")
  deploy --skip-checks ".#$target" --boot -- --print-build-logs
  printf '%s✔ Boot profile staged%s for %s %s(activates on next reboot)%s\n' "$GREEN" "$RESET" "$target" "$DIM" "$RESET"
  echo "::endgroup::"

  if [ "${GITHUB_STEP_SUMMARY:-}" != "" ]; then
    {
      printf '## Bootloader Staging: \140%s\140\n\n' "$target"
      printf -- '- **Action**: \140boot\140 (activates on next reboot)\n'
      printf -- '- **Staged System**: \140%s\140\n' "$new_system"
      printf -- '- **Status**: Succeeded\n\n'
    } >>"$GITHUB_STEP_SUMMARY"
  fi
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
