#!/usr/bin/env bash
set -euo pipefail

base_branch="${AUTO_MAINTENANCE_BASE_BRANCH:-develop}"
bot_branch="${AUTO_MAINTENANCE_BOT_BRANCH:-bot/auto-maintenance}"
api_url="${AUTO_MAINTENANCE_API_URL:-http://127.0.0.1:24200/api/v1}"
repository="${AUTO_MAINTENANCE_REPOSITORY:-yi/nixos}"
prompt_file="${AUTO_MAINTENANCE_PROMPT_FILE:-ci/auto-maintenance-prompt.md}"
drop_to_none="${AUTO_MAINTENANCE_DROP_TO_NONE:-/run/wrappers/bin/drop-to-none}"
model="${AUTO_MAINTENANCE_MODEL:-gemini-3.8-flash-medium}"
# Forgejo CI and the GitHub push mirror's runner execute these as nix-builder,
# outside the Nix sandbox, as soon as the bot branch is pushed.
protected_paths='^(\.forgejo|\.gitea|\.github|ci|nix/scripts)/'

agy_token="${AGY_OAUTH_TOKEN:?AGY_OAUTH_TOKEN is empty}"
forgejo_token="${AUTO_MAINTENANCE_TOKEN:?AUTO_MAINTENANCE_TOKEN is empty}"
unset AGY_OAUTH_TOKEN AUTO_MAINTENANCE_TOKEN

as_none() {
  "$drop_to_none" --reuid=none --regid=none --keep-groups --no-new-privs -- "$@"
}

sandbox() {
  as_none bwrap \
    --unshare-all \
    --share-net \
    --die-with-parent \
    --new-session \
    --clearenv \
    --ro-bind /nix /nix \
    --ro-bind /etc /etc \
    --ro-bind /run/current-system /run/current-system \
    --ro-bind /bin /bin \
    --ro-bind /usr/bin /usr/bin \
    --ro-bind-try /lib64 /lib64 \
    --dev /dev \
    --proc /proc \
    --tmpfs /tmp \
    --tmpfs /home/none \
    --bind "$work" /work \
    --chdir /work \
    --setenv HOME /home/none \
    --setenv USER none \
    --setenv PATH "$PATH:/run/current-system/sw/bin" \
    "$@"
}

verify() {
  sandbox -- nix flake check --no-build &&
    sandbox -- nix-fast-build --flake ".#hydraJobs" --skip-cached --retries 1 --eval-workers 2
}

api() {
  curl --fail --silent --show-error \
    --header @<(printf 'Authorization: token %s\n' "$forgejo_token") \
    "$@"
}

git config core.hooksPath /dev/null
git config user.name "Auto Maintenance"
git config user.email "auto-maintenance@fufu.land"
git fetch --quiet --prune origin "+refs/heads/*:refs/remotes/origin/*"
git switch --quiet --force-create "$bot_branch" "refs/remotes/origin/$base_branch"
echo "auto-maintenance: $bot_branch reset to $base_branch at $(git rev-parse --short HEAD)"

# Resolved from the reviewed lockfile; the update below only touches the copy.
agy="$(nix build --no-link --print-out-paths --inputs-from . "antigravity-nix#google-antigravity-cli")/bin/agy"

work="$(as_none mktemp -d)"
trap 'as_none rm -rf "$work"' EXIT
as_none chmod 0755 "$work"
git archive HEAD | as_none tar -x -C "$work"

sandbox -- nix flake update
if git --work-tree="$work" diff --quiet -- flake.lock; then
  echo "auto-maintenance: flake.lock is already up to date"
  exit 0
fi

if ! log="$(verify 2>&1 | tee >(cat >&2))"; then
  echo "auto-maintenance: verification failed; summoning the sandboxed agent"
  prompt="$(cat "$prompt_file")

Verification failure output (last 200 lines):
~~~text
$(tail -n 200 <<<"$log")
~~~"
  sandbox \
    --perms 0600 --file 3 /home/none/.gemini/antigravity-cli/antigravity-oauth-token \
    -- "$agy" --dangerously-skip-permissions --mode accept-edits --model "$model" --print "$prompt" \
    3< <(printf '%s' "$agy_token")
fi

git --work-tree="$work" add --all
changed="$(git diff --cached --name-only --no-renames)"
if grep -E "$protected_paths" <<<"$changed"; then
  echo "auto-maintenance: refusing to publish changes to the runner-executed paths above" >&2
  exit 1
fi
git diff --cached --check

commit_msg="chore(flake): update flake.lock"
if [ "$changed" != "flake.lock" ]; then
  commit_msg="chore(flake): update flake.lock and repair build"
fi
git commit --quiet --message "$commit_msg"

bot_ref="refs/remotes/origin/$bot_branch"
if git rev-parse --quiet --verify "$bot_ref" >/dev/null && git diff --quiet "$bot_ref" HEAD; then
  echo "auto-maintenance: $bot_branch already carries this tree"
else
  basic="$(printf 'auto-maintenance:%s' "$forgejo_token" | base64 --wrap=0)"
  GIT_TERMINAL_PROMPT=0 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=http.extraHeader \
    GIT_CONFIG_VALUE_0="Authorization: Basic $basic" \
    git push --quiet --force-with-lease="refs/heads/$bot_branch" origin "HEAD:refs/heads/$bot_branch"
  echo "auto-maintenance: pushed $(git rev-parse --short HEAD) to $bot_branch"
fi

pr_url="$(
  api "$api_url/repos/$repository/pulls?state=open&limit=50" |
    jq -r --arg head "$bot_branch" --arg base "$base_branch" \
      'map(select(.head.ref == $head and .base.ref == $base)) | .[0].html_url // empty'
)"
if [ "$pr_url" = "" ]; then
  pr_url="$(
    jq -n --arg head "$bot_branch" --arg base "$base_branch" '{
      title: "chore(flake): update flake.lock",
      head: $head,
      base: $base,
      body: "Prepared by Auto Maintenance: a deterministic `nix flake update`, plus a sandboxed agent repair when verification failed."
    }' |
      api --header 'Content-Type: application/json' --request POST --data-binary @- \
        "$api_url/repos/$repository/pulls" |
      jq -er '.html_url'
  )"
  echo "auto-maintenance: created pull request: $pr_url"
else
  echo "auto-maintenance: open pull request: $pr_url"
fi
