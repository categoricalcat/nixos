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

if [[ "$(hostname)" == yifuwuqi ]]; then
  FLAKE_URI="$FLAKE_DIR"
else
  FLAKE_URI="git+ssh://${REMOTE}:${PORT}${FLAKE_DIR}"
fi

echo "nh os ${args[*]} -H $TARGET_HOST $FLAKE_URI"
read -n 1 -s -r -p "Press any key to continue..."
echo
exec nh os "${args[@]}" -H "$TARGET_HOST" "$FLAKE_URI"
