#!/usr/bin/env bash
set -euo pipefail

HOSTS=("yixiaoqing" "yitaishi" "yifuwuqi" "yirukou" "yichuang" "yijia")
TARGET_HOST="${1:-}"

if [ -z "$TARGET_HOST" ]; then
  if command -v fzf >/dev/null 2>&1 && [ -t 0 ]; then
    TARGET_HOST=$(printf '%s\n' "${HOSTS[@]}" | fzf --prompt="Select host to inspect: ")
  elif [ -n "${HOST:-}" ]; then
    TARGET_HOST="$HOST"
  else
    TARGET_HOST="yifuwuqi"
  fi
fi

FLAKE_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if [ "$TARGET_HOST" = "yijia" ]; then
  EXPR="(builtins.getFlake \"$FLAKE_DIR\").homeConfigurations.yijia.config"
else
  EXPR="(builtins.getFlake \"$FLAKE_DIR\").nixosConfigurations.\"$TARGET_HOST\".config"
fi

echo "Opening REPL for $TARGET_HOST..."
exec nix repl --expr "$EXPR"
