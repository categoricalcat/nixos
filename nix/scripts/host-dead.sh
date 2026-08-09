#!/usr/bin/env bash
set -euo pipefail

FLAKE_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "=== Searching for dead code & unused bindings (deadnix) ==="
if command -v deadnix >/dev/null 2>&1; then
  deadnix "$FLAKE_DIR/hosts" "$FLAKE_DIR/modules" "$FLAKE_DIR/users" "$FLAKE_DIR/nix" || true
else
  echo "deadnix command not found."
fi

echo ""
echo "=== Running statix check ==="
if command -v statix >/dev/null 2>&1; then
  statix check "$FLAKE_DIR" || true
else
  echo "statix command not found."
fi
