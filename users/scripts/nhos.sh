#! /usr/bin/env bash
set -euo pipefail

FLAKE_DIR="$(pwd)"
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  FLAKE_DIR="$(git rev-parse --show-toplevel)"
fi

REMOTE="yifuwuqi.lan"
PORT="24212"
TARGET_HOST="${HOST:-$(hostname)}"
args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    dry-build)
      args+=("build")
      shift
      ;;
    -h)
      REMOTE="$2"
      shift 2
      ;;
    -p|--port)
      PORT="$2"
      shift 2
      ;;
    -H)
      TARGET_HOST="$2"
      shift 2
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

exec nh os "${args[@]}" -H "$TARGET_HOST" "git+ssh://${REMOTE}:${PORT}${FLAKE_DIR}"
