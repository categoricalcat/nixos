#!/usr/bin/env bash
# Dedicated CI/CD Deployment Key Management
# Mints a deployment keypair in tmpfs when missing from secrets/keys.nix (or on --rotate),
# and prints SOPS ingestion instructions.
# usage (from the repo root): ensure-ci-key <hostname> <rotate: true|false>
set -euo pipefail

hostname="$1"
rotate="$2"

ci_dir="/run/ci-deploy-key"
ci_keys_dir="$ci_dir/keys"
ci_priv="$ci_keys_dir/deploy_ed25519"
ci_pub="$ci_priv.pub"

is_registered=false
if grep -Eq 'deployPublicKey\s*=\s*"ssh-ed25519' secrets/keys.nix 2>/dev/null; then
  is_registered=true
fi

if [ "$is_registered" = "false" ] || [ "$rotate" = "true" ]; then
  mkdir -p "$ci_keys_dir"
  chmod 0700 "$ci_dir" "$ci_keys_dir"
  chown -R root:root "$ci_dir"

  echo "-> Generating CI deployment key in tmpfs ($ci_priv)..."
  rm -f "$ci_priv" "$ci_pub"
  ssh-keygen -t ed25519 -N "" -f "$ci_priv" -C "nix-builder@$hostname"
  chmod 0600 "$ci_priv"
  chmod 0644 "$ci_pub"
  chown -R root:root "$ci_dir"

  ci_pub_content=$(cat "$ci_pub")

  echo ""
  echo "=========================================="
  echo "     Add to secrets/keys.nix (ci)         "
  echo "=========================================="
  printf '  ci = {\n    deployPublicKey = "%s";\n  };\n' "$ci_pub_content"
  echo ""
  echo "=========================================="
  echo "  To ingest private key into SOPS:        "
  echo "=========================================="
  echo "sops set secrets/secrets.yaml '[\"keys\"][\"deploy\"]' \"\$(jq -Rs . < $ci_priv)\""
  echo "shred -u $ci_priv"
  echo "rm -rf $ci_dir"
  echo ""
else
  echo "-> ci key ok"
fi
