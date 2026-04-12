#!/usr/bin/env bash

set -euo pipefail
config_dir="$HOME/.config/syncthing"

if [ -f "$config_dir/cert.pem" ]; then
  echo "Keys already exist at $config_dir"
  syncthing device-id --home="$config_dir"
  exit 0
fi

mkdir -p "$config_dir"
syncthing generate --home="$config_dir"

echo "Device ID for $(hostname):"
syncthing device-id --home="$config_dir"
