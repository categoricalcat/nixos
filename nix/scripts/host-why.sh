#!/usr/bin/env bash
set -euo pipefail

HOSTS=("yixiaoqing" "yitaishi" "yifuwuqi" "yirukou" "yichuang")
TARGET_HOST="${1:-}"
TARGET_PKG="${2:-}"

if [ "$TARGET_HOST" = "" ] || [ "$TARGET_PKG" = "" ]; then
  if command -v fzf >/dev/null 2>&1 && [ -t 0 ]; then
    [ "$TARGET_HOST" = "" ] && TARGET_HOST=$(printf '%s\n' "${HOSTS[@]}" | fzf --prompt="Select host: ")
    [ "$TARGET_PKG" = "" ] && read -rp "Package to trace: " TARGET_PKG
  else
    echo "Usage: host-why <host> <package>"
    exit 1
  fi
fi

FLAKE_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ATTR="nixosConfigurations.${TARGET_HOST}.config.system.build.toplevel"

DRV=$(nix eval --raw "${FLAKE_DIR}#${ATTR}.drvPath")
OUT=$(nix-store -r "$DRV")

MATCHES=$(nix path-info -r "$OUT" | grep -i "$TARGET_PKG")

for match in "${MATCHES[@]}"; do
  echo "=== $match ==="
  nix why-depends "$OUT" "$match"
done
