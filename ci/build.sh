#!/usr/bin/env bash
set -euo pipefail

GREEN=$'\033[1;32m'
DIM=$'\033[2m'
RESET=$'\033[0m'

echo "::group::Preflight: builder probe & Attic login"

BUILDER_ARGS=()
BUILDER_STATUS="local only (yitaishi offline)"
if timeout 2 bash -c '</dev/tcp/yitaishi.ts/24212' 2>/dev/null || timeout 2 bash -c '</dev/tcp/yitaishi.nb/24212' 2>/dev/null; then
  printf '%s✔ yitaishi online%s — registering ssh-ng remote builder\n' "$GREEN" "$RESET"
  b="ssh-ng://yitaishi x86_64-linux - 16 100 kvm,nixos-test,benchmark,big-parallel"
  [ -f /etc/nix/machines ] && b="@/etc/nix/machines ; $b"
  BUILDER_ARGS=(--option builders "$b")
  BUILDER_STATUS="yitaishi (ssh-ng, 16 cores)"
else
  printf '%s• yitaishi offline%s — building locally on %s\n' "$DIM" "$RESET" "$(hostname)"
fi

attic login "$ATTIC_CACHE_NAME" "$ATTIC_INTERNAL_URL" "${ATTIC_TOKEN:?attic token is empty}"
printf '%s✔ Attic authenticated%s (%s @ %s)\n' "$GREEN" "$RESET" "$ATTIC_CACHE_NAME" "$ATTIC_INTERNAL_URL"

echo "::endgroup::"

if [ "${GITHUB_STEP_SUMMARY:-}" != "" ]; then
  {
    printf '| Field | Value |\n| :--- | :--- |\n'
    printf '| **Runner** | \140%s\140 |\n' "$(hostname)"
    printf '| **Remote Builder** | \140%s\140 |\n' "$BUILDER_STATUS"
    printf '| **Attic Cache** | \140%s\140 (\140%s\140) |\n' "$ATTIC_CACHE_NAME" "$ATTIC_INTERNAL_URL"
    printf '| **Commit** | \140%s\140 (\140%s\140) |\n\n' "${GITHUB_SHA:0:7}" "${GITHUB_REF_NAME:-unknown}"
  } >>"$GITHUB_STEP_SUMMARY"
fi

FAST_BUILD_CMD=(nix-fast-build)
if ! command -v nix-fast-build >/dev/null 2>&1; then
  FAST_BUILD_CMD=(nix run --inputs-from . "nixpkgs#lixPackageSets.lix_2_96.nix-fast-build" --)
fi

"${FAST_BUILD_CMD[@]}" "${BUILDER_ARGS[@]}" \
  --flake ".#hydraJobs" \
  --skip-cached \
  --retries 1 \
  --eval-workers 2 \
  --attic-cache "$ATTIC_CACHE_NAME:$ATTIC_CACHE_NAME" \
  --attic-ignore-upstream-cache-filter

# Keep one GC root per deploy host so attic-closure-keeper retains undeployed closures across weekly GC.
case "${GITHUB_REF_NAME:-}" in
develop | bot/auto-maintenance)
  echo "::group::GC roots for $GITHUB_REF_NAME"
  root_dir="/var/lib/nix-builder/gcroots/${GITHUB_REF_NAME//\//-}"
  mkdir -p "$root_dir"
  nix eval --json .#deploy.nodes --apply builtins.attrNames | jq -r '.[]' | while read -r host; do
    if nix build --out-link "$root_dir/$host" ".#nixosConfigurations.$host.config.system.build.toplevel"; then
      printf '%s✔ Rooted%s %s\n' "$GREEN" "$RESET" "$host"
    else
      echo "::warning::could not root the $host toplevel for $GITHUB_REF_NAME"
    fi
  done
  echo "::endgroup::"
  ;;
esac
