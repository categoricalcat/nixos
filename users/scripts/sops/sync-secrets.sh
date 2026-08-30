#!/usr/bin/env bash
# Permissions enforcement, secrets syncing to /persist, and .sops.yaml generation.

sync_secrets() {
  echo "-> setup /persist/keys/sops permissions"
  mkdir -p /persist/keys
  chown root:root /persist/keys
  chmod 0755 /persist/keys
  mkdir -p /persist/keys/sops
  chown root:wheel /persist/keys/sops
  chmod 0770 /persist/keys/sops

  echo "-> syncing secrets to /persist/keys/sops/secrets.yaml"
  if [ -f "secrets/secrets.yaml" ] && ! cmp -s secrets/secrets.yaml /persist/keys/sops/secrets.yaml; then
    echo "-> refreshing /persist/keys/sops/secrets.yaml from repo"
    install -m 0660 -o root -g wheel secrets/secrets.yaml /persist/keys/sops/secrets.yaml
  fi

  if [ -f /persist/keys/sops/secrets.yaml ]; then
    chown root:wheel /persist/keys/sops/secrets.yaml
    chmod 0660 /persist/keys/sops/secrets.yaml
  fi

  echo "-> generate .sops.yaml"
  # shellcheck disable=SC2024
  runuser -u yi -- nix eval --raw -f secrets/generate-sops-yaml.nix >.sops.yaml
  chown yi .sops.yaml
}
