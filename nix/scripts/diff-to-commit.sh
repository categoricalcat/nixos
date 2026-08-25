#!/usr/bin/env bash
set -euo pipefail

agent="${1:-agy}"

diff=$(git diff --cached)
if [ "$diff" = "" ]; then
  echo "No staged changes found."
  exit 1
fi

stat=$(git diff --cached --stat)
max_diff_len=50000
if [ "${#diff}" -gt "$max_diff_len" ]; then
  diff="${diff:0:max_diff_len}"$'\n\n[... diff truncated due to size ...]'
fi

echo "Generating commit message using nxd-$agent..."
msg_file="$(git rev-parse --git-dir)/COMMIT_EDITMSG"

msg="$(nxd-"$agent" --print "$(
  cat <<EOF
Write a concise git commit message for this staged diff.
Output ONLY the commit message itself (no markdown blocks or preamble).

Changed files:
$stat

Diff:
$diff
EOF
)")"

if [ "$msg" = "" ]; then
  echo "Failed to generate commit message."
  exit 1
fi

printf '%s\n' "$msg" >"$msg_file"
exec git commit -e -F "$msg_file"
