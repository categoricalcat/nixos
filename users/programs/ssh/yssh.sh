#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <hostName> <target1> [target2...] [-- [user] [ssh_args...]]" >&2
  exit 1
fi

hostName=$1
shift

targets=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do
  targets+=("$1")
  shift
done

if [ $# -gt 0 ] && [ "$1" = "--" ]; then
  shift
fi

REMOTE_USER="${USER:-yi}"
ssh_args=()

if [ $# -gt 0 ] && [[ ! "$1" =~ ^- ]]; then
    REMOTE_USER="$1"
    shift
fi

while [[ $# -gt 0 ]]; do
    ssh_args+=("$1")
    shift
done

temp_file=$(mktemp)
pids=()

# Test each target concurrently with a real SSH authentication test
for target in "${targets[@]}"; do
  (
    # BatchMode=yes prevents interactive password prompts
    # ConnectTimeout limits TCP wait
    # "exit 0" immediately terminates upon successful auth
    if ssh -q -o BatchMode=yes -o ConnectTimeout=2 "${ssh_args[@]}" "${REMOTE_USER}@$target" exit 0 2>/dev/null; then
      echo "$target" > "$temp_file"
    fi
  ) &
  pids+=($!)
done

# Wait for the first success or all to fail
winner=""
while [ ${#pids[@]} -gt 0 ]; do
  wait -n 2>/dev/null || true
  if [ -s "$temp_file" ]; then
    winner=$(cat "$temp_file")
    break
  fi
  
  # Check which PIDs are still alive
  new_pids=()
  for pid in "${pids[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      new_pids+=("$pid")
    fi
  done
  pids=("${new_pids[@]}")
done

# Cleanup remaining jobs and temp file
for pid in "${pids[@]}"; do
  kill "$pid" 2>/dev/null || true
done
rm -f "$temp_file"

if [ -z "$winner" ]; then
  echo "Error: Could not reach $hostName on any route (or authentication failed)." >&2
  exit 1
fi

echo "=> Connecting to ${REMOTE_USER}@$winner (fastest route)"

exec ssh "${ssh_args[@]}" "${REMOTE_USER}@$winner"
