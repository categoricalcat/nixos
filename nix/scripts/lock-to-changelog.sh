#!/usr/bin/env bash
set -euo pipefail

agent="${1:-agy}"
instructions="${2:-}"

# 1. Detect old vs new flake.lock
old="HEAD~1:flake.lock"
new="flake.lock"
if git diff --cached --name-only | grep -q "^flake.lock$"; then
  old="HEAD:flake.lock"
  new=":flake.lock"
elif git diff --name-only | grep -q "^flake.lock$"; then
  old="HEAD:flake.lock"
fi

# 2. Extract changed inputs and fetch commit logs
summary=""
while IFS=$'\t' read -r name owner repo old_rev new_rev; do
  [ "$name" = "" ] && continue
  logs=""
  if [ "$owner" != "" ] && [ "$repo" != "" ] && [ "$old_rev" != "" ] && [ "$new_rev" != "" ]; then
    url="https://api.github.com/repos/$owner/$repo/compare/$old_rev...$new_rev"
    resp=""
    if [ "${GITHUB_TOKEN:-}" != "" ]; then
      resp=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" "$url" || true)
      # If Forgejo's token caused a 401 on api.github.com, retry unauthenticated
      if echo "$resp" | jq -e '.message? == "Bad credentials"' >/dev/null 2>&1; then
        resp=$(curl -s "$url" || true)
      fi
    else
      resp=$(curl -s "$url" || true)
    fi
    logs=$(echo "$resp" | jq -r '.commits[:15][]?.commit.message | split("\n")[0] | "  * " + .' 2>/dev/null || true)
  fi
  summary+=$'\n'"- input '$name' (${old_rev:0:7}..${new_rev:0:7}):"$'\n'"$logs"$'\n'
done < <(jq -n -r '
  ($old[0].nodes // {}) as $o | ($new[0].nodes // {}) as $n |
  (($n | keys) + ($o | keys) | unique)[] | select(. != "root") | . as $k |
  ($o[$k].locked // {}) as $ol | ($n[$k].locked // {}) as $nl |
  select($ol != $nl and ($ol.rev != $nl.rev or $ol.narHash != $nl.narHash)) |
  [$k, ($nl.owner // $ol.owner // (if $k == "nixpkgs" then "NixOS" else "" end)),
       ($nl.repo  // $ol.repo  // (if $k == "nixpkgs" then "nixpkgs" else "" end)),
       ($ol.rev // ""), ($nl.rev // "")] | @tsv
' --slurpfile old <(git show "$old" 2>/dev/null || echo '{}') \
  --slurpfile new <(if [ "$new" = "flake.lock" ]; then cat flake.lock; else git show "$new"; fi))

[ "$summary" = "" ] && {
  echo "No changes found in flake.lock."
  exit 0
}

# 3. Call AI agent or fallback to raw summary
if [ "${CI:-}" != "" ] || ! command -v "nxd-$agent" >/dev/null 2>&1; then
  echo "Using direct input commit summary (running in CI or nxd-$agent not in PATH)..." >&2
  changelog="### Flake Lock Updates"$'\n'"$summary"
else
  flags=(--print)
  [ "$agent" = "agy" ] && flags=(--dangerously-skip-permissions --print)
  [ "$agent" = "agent" ] && flags=(--mode ask --trust --print --model auto)

  prompt="Write patch notes for this flake.lock update in plain text (no markdown #, **, or backticks).
Group changes by component, highlight breaking changes and major features from commit logs:
${instructions:+Extra instructions: $instructions}

$summary"

  echo "Generating changelog using nxd-$agent..." >&2
  changelog="$(nxd-"$agent" "${flags[@]}" "$prompt" </dev/null 2>/dev/null || printf '%s\n' "$summary")"
fi

# 4. Output
printf '%s\n' "$changelog"
[ "${GITHUB_STEP_SUMMARY:-}" != "" ] && printf '\n%s\n' "$changelog" >>"$GITHUB_STEP_SUMMARY"
