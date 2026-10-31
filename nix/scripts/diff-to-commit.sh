#!/usr/bin/env bash
set -euo pipefail

agent="${1:-agy}"
instructions="${2:-}"

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

extra_instructions=""
if [ "$instructions" != "" ]; then
  extra_instructions="
Extra instructions:
$instructions
"
fi

echo "Generating commit message using nxd-$agent..."
msg_file="$(git rev-parse --git-dir)/COMMIT_EDITMSG"

flags=(--print)
if [ "$agent" = "agy" ]; then
  # agy ignores --mode plan once slash commands are disabled; deny rules keep the run text-only.
  flags=(--sandbox --disable-slash-commands
    --settings '{"permissions":{"deny":["write_file(*)","command(*)","read_url(*)","execute_url(*)","mcp(*)"]}}'
    --print)
elif [ "$agent" = "agent" ]; then
  flags=(--mode ask --trust --print --model auto)
fi

nxd-"$agent" "${flags[@]}" "$(
  cat <<EOF
Write a concise git commit message for this staged diff.
Output ONLY the commit message itself (no markdown blocks or preamble).
$extra_instructions
Changed files:
$stat

Diff:
$diff
EOF
)" </dev/null | tee "$msg_file"

if [ ! -s "$msg_file" ] || [ "$(tr -d '[:space:]' <"$msg_file")" = "" ]; then
  echo "Failed to generate commit message."
  exit 1
fi

exec git commit -e -F "$msg_file"
