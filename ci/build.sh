#!/usr/bin/env bash
set -euo pipefail

GREEN=$'\033[1;32m'
DIM=$'\033[2m'
RESET=$'\033[0m'
ref_name="${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-}}"

echo "::group::Preflight: builder probe & Attic login"

BUILDER_ARGS=()
BUILDER_STATUS="local only (yitaishi offline)"
LOCAL_JOBS="$(nix config show --json | jq -er '."max-jobs".value | numbers')"
REMOTE_JOBS=0
if timeout 2 bash -c '</dev/tcp/yitaishi.ts/24212' 2>/dev/null || timeout 2 bash -c '</dev/tcp/yitaishi.nb/24212' 2>/dev/null; then
  printf '%s✔ yitaishi online%s — registering ssh-ng remote builder\n' "$GREEN" "$RESET"
  REMOTE_JOBS=16
  b="ssh-ng://yitaishi x86_64-linux - $REMOTE_JOBS 100 kvm,nixos-test,benchmark,big-parallel"
  [ -f /etc/nix/machines ] && b="@/etc/nix/machines ; $b"
  BUILDER_ARGS=(--option builders "$b")
  BUILDER_STATUS="yitaishi (ssh-ng, $REMOTE_JOBS jobs)"
else
  printf '%s• yitaishi offline%s — building locally on %s\n' "$DIM" "$RESET" "$(hostname)"
fi
TOTAL_JOBS=$((LOCAL_JOBS + REMOTE_JOBS))

attic login "$ATTIC_CACHE_NAME" "$ATTIC_INTERNAL_URL" "${ATTIC_TOKEN:?attic token is empty}"
printf '%s✔ Attic authenticated%s (%s @ %s)\n' "$GREEN" "$RESET" "$ATTIC_CACHE_NAME" "$ATTIC_INTERNAL_URL"

echo "::endgroup::"

if [ "${GITHUB_STEP_SUMMARY:-}" != "" ]; then
  {
    printf '| Field | Value |\n| :--- | :--- |\n'
    printf '| **Runner** | \140%s\140 |\n' "$(hostname)"
    printf '| **Remote Builder** | \140%s\140 |\n' "$BUILDER_STATUS"
    printf '| **Build Workers** | \140%s\140 (\140%s local + %s remote\140) |\n' "$TOTAL_JOBS" "$LOCAL_JOBS" "$REMOTE_JOBS"
    printf '| **Attic Cache** | \140%s\140 (\140%s\140) |\n' "$ATTIC_CACHE_NAME" "$ATTIC_INTERNAL_URL"
    printf '| **Commit** | \140%s\140 (\140%s\140) |\n\n' "${GITHUB_SHA:0:7}" "${ref_name:-unknown}"
  } >>"$GITHUB_STEP_SUMMARY"
fi

EVAL_JOBS_CMD=(nix-eval-jobs)
if ! command -v nix-eval-jobs >/dev/null 2>&1; then
  EVAL_JOBS_CMD=(nix run --inputs-from . "nixpkgs#lixPackageSets.lix_2_96.nix-eval-jobs" --)
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/gcroots" "$work/roots"
jobs="$work/jobs.jsonl"
failed=0

"${EVAL_JOBS_CMD[@]}" "${BUILDER_ARGS[@]}" \
  --flake ".#hydraJobs" \
  --force-recurse \
  --check-cache-status \
  --show-trace \
  --workers 2 \
  --gc-roots-dir "$work/gcroots" >"$jobs" || failed=1
jq -r 'select(.error) | "::error::evaluation of \(.attr) failed\n\(.error)"' "$jobs"

mapfile -t drvs < <(jq -r 'select(.error == null and (.isCached | not)) | "\(.drvPath)^*"' "$jobs")
jq -rs --argjson build "${#drvs[@]}" \
  '"\(length) jobs: \(map(select(.isCached)) | length) cached, \($build) to build, \(map(select(.error)) | length) failed to evaluate"' "$jobs"
# One `nix build --keep-going` for every job: Nix caches no build failures, so
# per-job builds would each retry a broken dependency they share.
if [ "${#drvs[@]}" -gt 0 ]; then
  nix build "${BUILDER_ARGS[@]}" --keep-going --print-build-logs --no-link "${drvs[@]}" || failed=1
fi

declare -A verdict=()
built=()
while IFS=$'\t' read -r attr state outs; do
  read -ra paths <<<"$outs"
  case "$state" in
  eval-error) failed=1 ;;
  build)
    # nix build creates no out-links once any job fails; root finished outputs before the push.
    if nix-store --check-validity "${paths[@]}" 2>/dev/null &&
      nix-store --add-root "$work/roots/$attr" --realise "${paths[@]}" >/dev/null; then
      state=built
      built+=("${paths[@]}")
    else
      state=failed
      failed=1
    fi
    ;;
  esac
  verdict[$attr]="$state"
done < <(jq -r '[.attr, (if .error then "eval-error" elif .isCached then "cached" else "build" end), ([.outputs // {} | .[] | strings] | join(" "))] | @tsv' "$jobs")

if [ "${#built[@]}" -gt 0 ]; then
  attic push --ignore-upstream-cache-filter "$ATTIC_CACHE_NAME:$ATTIC_CACHE_NAME" "${built[@]}" || failed=1
fi

# Keep one GC root per deploy host so attic-closure-keeper retains undeployed closures across weekly GC.
case "$ref_name" in
develop | bot/auto-maintenance)
  echo "::group::GC roots for $ref_name"
  root_dir="/var/lib/nix-builder/gcroots/${ref_name//\//-}"
  mkdir -p "$root_dir"
  nix eval --json .#deploy.nodes --apply builtins.attrNames | jq -r '.[]' | while read -r host; do
    job="nixos-$host"
    toplevel="$(jq -r --arg attr "$job" 'select(.attr == $attr) | .outputs.out // empty' "$jobs")"
    if [[ ${verdict[$job]:-} =~ ^(built|cached)$ ]] && nix build --out-link "$root_dir/$host" "$toplevel"; then
      printf '%s✔ Rooted%s %s\n' "$GREEN" "$RESET" "$host"
    else
      echo "::warning::could not root the $host toplevel for $ref_name"
    fi
  done
  echo "::endgroup::"
  ;;
esac

report() {
  printf '| Job | Result |\n| :--- | :--- |\n'
  jq -r '.attr' "$jobs" | sort | while read -r attr; do
    printf '| \140%s\140 | %s |\n' "$attr" "${verdict[$attr]}"
  done
}
report
[ "${GITHUB_STEP_SUMMARY:-}" = "" ] || report >>"$GITHUB_STEP_SUMMARY"
exit "$failed"
