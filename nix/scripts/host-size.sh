#!/usr/bin/env bash
set -euo pipefail

HOSTS=("yixiaoqing" "yitaishi" "yifuwuqi" "yirukou" "yichuang" "yijia")
TARGET_HOST="${1:-}"

if [ -z "$TARGET_HOST" ]; then
  if command -v fzf >/dev/null 2>&1 && [ -t 0 ]; then
    TARGET_HOST=$(printf '%s\n' "${HOSTS[@]}" | fzf --prompt="Select host for size breakdown: ")
  else
    echo "Usage: host-size <host>"
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

echo "Evaluating derivation path for $TARGET_HOST..."
DRV=$(nix eval --raw "${FLAKE_DIR}#${ATTR}.drvPath")
echo "Building output path for $TARGET_HOST..."
OUT=$(nix-store -r "$DRV")

echo ""
echo "=== Top 25 packages by closure size for $TARGET_HOST ==="
nix path-info -r -S -h "$OUT" | sort -h -k 2 | tail -n 25
