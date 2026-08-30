#!/usr/bin/env bash
set -euo pipefail

HOST1="${1:-}"
HOST2="${2:-}"
HOSTS=("yixiaoqing" "yitaishi" "yifuwuqi" "yirukou" "yichuang" "yijia")

if [ "$HOST1" = "" ] || [ "$HOST2" = "" ]; then
  if command -v fzf >/dev/null 2>&1 && [ -t 0 ]; then
    echo "Select first host for diff:"
    HOST1=$(printf '%s\n' "${HOSTS[@]}" | fzf --prompt="Select host 1: ")
    echo "Select second host for diff:"
    HOST2=$(printf '%s\n' "${HOSTS[@]}" | fzf --prompt="Select host 2: ")
  else
    echo "Usage: host-diff <host1> <host2>"
    echo "Example: host-diff yixiaoqing yifuwuqi"
    echo "Available hosts: ${HOSTS[*]}"
    exit 1
  fi
fi

if [ "$HOST1" = "" ] || [ "$HOST2" = "" ]; then
  echo "Both hosts must be selected."
  exit 1
fi

FLAKE_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

get_attr() {
  local h="$1"
  if [ "$h" = "yijia" ]; then
    echo "homeConfigurations.yijia.activationPackage"
  else
    echo "nixosConfigurations.${h}.config.system.build.toplevel"
  fi
}

ATTR1=$(get_attr "$HOST1")
ATTR2=$(get_attr "$HOST2")

echo "Building closure for $HOST1..."
DRV1=$(nix eval --raw "${FLAKE_DIR}#${ATTR1}.drvPath")
OUT1=$(nix-store -r "$DRV1")

echo "Building closure for $HOST2..."
DRV2=$(nix eval --raw "${FLAKE_DIR}#${ATTR2}.drvPath")
OUT2=$(nix-store -r "$DRV2")

echo ""
echo "=== Diffing $HOST1 vs $HOST2 ==="
if command -v nvd >/dev/null 2>&1; then
  nvd diff "$OUT1" "$OUT2"
else
  nix store diff-closures "$OUT1" "$OUT2"
fi
