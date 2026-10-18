#!/usr/bin/env bash
set -euo pipefail

exec bash "$(dirname "$0")/sops/setup.sh" "$@"
