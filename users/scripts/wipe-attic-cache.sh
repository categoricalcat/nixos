#!/usr/bin/env bash
set -e

attic_cli() {
  if [ "$EUID" -eq 0 ]; then
    sudo -u "${SUDO_USER:-yi}" HOME="$(getent passwd "${SUDO_USER:-yi}" | cut -d: -f6)" nix run github:zhaofengli/attic#attic -- "$@"
  else
    nix run github:zhaofengli/attic#attic -- "$@"
  fi
}

trap 'sudo systemctl start atticd.service 2>/dev/null; attic_cli cache configure yi --retention-period 15d' EXIT

attic_cli cache configure yi --retention-period '1s'
sleep 4

ATTICD_BIN=$(systemctl show atticd.service -P ExecStart | grep -o 'path=[^ ;]*' | cut -d= -f2)
ATTICD_CONF=$(systemctl show atticd.service -P ExecStart | grep -o '\-f [^ ]*' | cut -d' ' -f2)

sudo systemctl stop atticd.service

sudo systemd-run --pty --wait \
  -p User=atticd \
  -p StateDirectory=atticd \
  -p DynamicUser=yes \
  -p EnvironmentFile=/run/secrets/tokens/attic-server-jwt-env \
  "$ATTICD_BIN" --mode garbage-collector-once --config "$ATTICD_CONF"
