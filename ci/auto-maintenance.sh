#!/usr/bin/env bash
set -euo pipefail

base_branch="${AUTO_MAINTENANCE_BASE_BRANCH:-develop}"
bot_branch="${AUTO_MAINTENANCE_BOT_BRANCH:-bot/auto-maintenance}"
api_url="${AUTO_MAINTENANCE_API_URL:-http://127.0.0.1:24200/api/v1}"
repository="${AUTO_MAINTENANCE_REPOSITORY:-yi/nixos}"
prompt_file="${AUTO_MAINTENANCE_PROMPT_FILE:-ci/auto-maintenance-prompt.md}"
agy="${AUTO_MAINTENANCE_AGY:-/run/current-system/sw/bin/nxd-agy}"
diff_to_commit="${AUTO_MAINTENANCE_DIFF_TO_COMMIT:-/run/current-system/sw/bin/diff-to-commit}"
model="${AUTO_MAINTENANCE_MODEL:-gemini-3.8-flash-medium}"

[[ -n ${AGY_OAUTH_TOKEN:-} ]] || {
  echo "AGY_OAUTH_TOKEN is empty" >&2
  exit 1
}
[[ -n ${AUTO_MAINTENANCE_TOKEN:-} ]] || {
  echo "AUTO_MAINTENANCE_TOKEN is empty" >&2
  exit 1
}

temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
agy_home="$temporary/agy-home"
forgejo_token=$AUTO_MAINTENANCE_TOKEN

install -d -m 0700 "$agy_home/.gemini/antigravity-cli"
printf '%s' "$AGY_OAUTH_TOKEN" \
  >"$agy_home/.gemini/antigravity-cli/antigravity-oauth-token"
chmod 0600 "$agy_home/.gemini/antigravity-cli/antigravity-oauth-token"
unset AGY_OAUTH_TOKEN AUTO_MAINTENANCE_TOKEN GITHUB_TOKEN FORGEJO_TOKEN

git config core.hooksPath /dev/null
git config user.name "Auto Maintenance"
git config user.email "auto-maintenance@fufu.land"
git fetch --prune origin '+refs/heads/*:refs/remotes/origin/*'

base_ref="refs/remotes/origin/$base_branch"
bot_ref="refs/remotes/origin/$bot_branch"
git show-ref --verify --quiet "$base_ref"

new_cycle=false
if ! git show-ref --verify --quiet "$bot_ref" ||
  git diff --quiet "$base_ref...$bot_ref"; then
  new_cycle=true
  cycle="new"
  start_ref=$base_ref
else
  cycle="continue"
  start_ref=$bot_ref
fi

git switch -C "$bot_branch" "$start_ref"
echo "auto-maintenance: cycle=$cycle start=$(git rev-parse --short HEAD)"

HOME="$agy_home" "$agy" \
  --dangerously-skip-permissions \
  --mode accept-edits \
  --model "$model" \
  --print \
  "$(cat "$prompt_file")

CYCLE: $cycle
BASE: $base_branch
BRANCH: $bot_branch"

git add -A
if git diff --cached --quiet; then
  echo "auto-maintenance: agent produced no changes"
  exit 0
fi

git diff --cached --check
HOME="$agy_home" GIT_EDITOR=: \
  "$diff_to_commit" agy "This is one incremental automatic-maintenance commit."
[[ -z $(git status --porcelain) ]] || {
  echo "diff-to-commit left uncommitted changes" >&2
  exit 1
}

git -c core.hooksPath=/dev/null push origin "HEAD:refs/heads/$bot_branch"

if [[ $new_cycle == true ]]; then
  pr_url=$(
    jq -n \
      --arg title "chore: incremental automatic maintenance" \
      --arg head "$bot_branch" \
      --arg base "$base_branch" \
      '{
        title: $title,
        head: $head,
        base: $base,
        body: "Each summon appends one agent-produced maintenance commit until this pull request is merged."
      }' |
      curl --fail --silent --show-error \
        --header "Authorization: token $forgejo_token" \
        --header 'Content-Type: application/json' \
        --request POST \
        --data-binary @- \
        "$api_url/repos/$repository/pulls" |
      jq -er '.html_url'
  )
  echo "auto-maintenance: created pull request: $pr_url"
fi
