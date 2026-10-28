#!/usr/bin/env bash
set -euo pipefail

GREEN=$'\033[1;32m'
CYAN=$'\033[1;36m'
DIM=$'\033[2m'
RESET=$'\033[0m'

RUNNER_HOST="yifuwuqi"
KNOWN_HOSTS=(yixiaoqing yitaishi yirukou "$RUNNER_HOST")
declare -A KNOWN_HOST_MAP
for h in "${KNOWN_HOSTS[@]}"; do KNOWN_HOST_MAP[$h]=1; done

ATTIC_INTERNAL_URL="${ATTIC_INTERNAL_URL:-http://yifuwuqi:24203}"
ATTIC_CACHE_NAME="${ATTIC_CACHE_NAME:-yi}"

usage() {
  echo "Usage: $0 <gate|dry|switch|boot|dry-activate|diff|deploy|1-diff|2-deploy> <host...>" >&2
  exit 1
}

if [ "$#" -eq 0 ]; then
  if ! [ -t 0 ] || ! command -v fzf >/dev/null 2>&1; then
    usage
  fi
  action="dry"
else
  action="$1"
  shift
fi

hosts=("$@")
if [ "${#hosts[@]}" -eq 0 ]; then
  if ! [ -t 0 ] || ! command -v fzf >/dev/null 2>&1; then
    usage
  fi
  selected=$(printf '%s\n' "${KNOWN_HOSTS[@]}" | fzf -m --prompt="Select host(s) to deploy (TAB to select multiple, Enter to confirm): ")
  [ "$selected" != "" ] || {
    echo "No hosts selected. Aborting." >&2
    exit 1
  }
  readarray -t hosts <<<"$selected"
fi

targets=()
has_runner=0
declare -A seen=()
for h in "${hosts[@]}"; do
  if [ "$h" = "all" ]; then
    targets=("${KNOWN_HOSTS[@]}")
    has_runner=0
    break
  fi
  [ "${KNOWN_HOST_MAP[$h]:-}" != "" ] || {
    echo "::error::Unknown host '$h'. Valid hosts: ${KNOWN_HOSTS[*]}" >&2
    exit 1
  }
  [ "${seen[$h]:-}" = "" ] || continue
  seen[$h]=1
  [ "$h" = "$RUNNER_HOST" ] && has_runner=1 || targets+=("$h")
done
[ "$has_runner" -eq 1 ] && targets+=("$RUNNER_HOST")

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

run_action() {
  local target="$1"
  case "$action" in
  gate) gate "$target" ;;
  dry | 1-diff)
    dry_activate "$target"
    diff_closure "$target"
    ;;
  dry-activate | dry-run) dry_activate "$target" ;;
  diff) diff_closure "$target" ;;
  switch | deploy | 2-deploy | live | apply) deploy_live "$target" ;;
  boot) deploy_boot "$target" ;;
  *)
    echo "Unknown action: $action" >&2
    usage
    ;;
  esac
}

for target in "${targets[@]}"; do
  run_action "$target"
done
