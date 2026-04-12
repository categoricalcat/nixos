#!/usr/bin/env bash

set -euo pipefail

sudo nix fmt
git add .
nix flake check -v
sudo nixos-rebuild --flake ".#$(hostname)" --upgrade --print-build-logs --show-trace dry-build
