#!/usr/bin/env bash
# Permissions enforcement, secrets syncing to /persist, and .sops.yaml generation.
# usage (from the repo root): sync-secrets
set -euo pipefail

# /persist/keys permission layout for install-time use, before a system
# exists to run the declarative rules. On booted hosts the same layout is
# enforced by systemd.tmpfiles.rules in secrets/sops.nix; the DR drill
# (secrets/test.nix) relies on those rules alone.
echo "-> setup /persist/keys/sops permissions"
install -d -m 0755 -o root -g root /persist/keys
install -d -m 0700 -o root -g root /persist/keys/sops

echo "-> syncing secrets to /persist/keys/sops/secrets.yaml"
if [ -f "secrets/secrets.yaml" ] && ! cmp -s secrets/secrets.yaml /persist/keys/sops/secrets.yaml; then
  echo "-> refreshing /persist/keys/sops/secrets.yaml from repo"
  install -m 0600 -o root -g root secrets/secrets.yaml /persist/keys/sops/secrets.yaml
fi

if [ -f /persist/keys/sops/secrets.yaml ]; then
  chown root:root /persist/keys/sops/secrets.yaml
  chmod 0600 /persist/keys/sops/secrets.yaml
fi

echo "-> generate .sops.yaml"
# shellcheck disable=SC2024
runuser -u yi -- env HOME=/home/yi nix eval --raw -f secrets/keys.nix sopsYaml >.sops.yaml
chown yi:yi .sops.yaml
