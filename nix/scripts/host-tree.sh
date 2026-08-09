#!/usr/bin/env bash
set -euo pipefail

HOSTS=("yixiaoqing" "yitaishi" "yifuwuqi" "yirukou" "yichuang" "yijia")
TARGET_HOST="${1:-}"

if [ -z "$TARGET_HOST" ]; then
  if command -v fzf >/dev/null 2>&1 && [ -t 0 ]; then
    TARGET_HOST=$(printf '%s\n' "${HOSTS[@]}" | fzf --prompt="Select host for nix-tree: ")
  else
    echo "Usage: host-tree <host> [nix-tree options]"
    echo "Available hosts: ${HOSTS[*]}"
    exit 1
  fi
fi

if [ -z "$TARGET_HOST" ]; then
  echo "No host selected."
  exit 1
fi

FLAKE_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if [ "$TARGET_HOST" = "yijia" ]; then
  ATTR="homeConfigurations.yijia.activationPackage"
else
  ATTR="nixosConfigurations.${TARGET_HOST}.config.system.build.toplevel"
fi

echo "Evaluating derivation for $TARGET_HOST..."
DRV=$(nix eval --raw "${FLAKE_DIR}#${ATTR}.drvPath")

echo "Building output path for $TARGET_HOST..."
OUT=$(nix-store -r "$DRV")

echo "Running nix-tree for $TARGET_HOST..."
exec nix-tree "$OUT" "${@:2}"
