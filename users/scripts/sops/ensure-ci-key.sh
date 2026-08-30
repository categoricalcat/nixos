#!/usr/bin/env bash
# Dedicated CI/CD Deployment Key Management
# Mints a deployment keypair in tmpfs on yifuwuqi when missing from secrets/keys.nix (or on --rotate),
# and prints SOPS ingestion instructions.

ensure_ci_key() {
  local hostname="$1"
  local rotate="$2"

  if [ "$hostname" != "yifuwuqi" ]; then
    return 0
  fi

  local ci_dir="/run/ci-deploy-key"
  local ci_keys_dir="$ci_dir/keys"
  local ci_priv="$ci_keys_dir/deploy_ed25519"
  local ci_pub="$ci_priv.pub"

  local is_registered=false
  if grep -Eq 'deployPublicKey\s*=\s*"ssh-ed25519' secrets/keys.nix 2>/dev/null; then
    is_registered=true
  fi

  if [ "$is_registered" = "false" ] || [ "$rotate" = "true" ]; then
    local target_user="${SUDO_USER:-yi}"
    local target_group="${SUDO_GID:-$target_user}"

    mkdir -p "$ci_keys_dir"
    chmod 0700 "$ci_dir" "$ci_keys_dir"
    chown -R "$target_user:$target_group" "$ci_dir"

    echo "-> Generating CI deployment key in tmpfs ($ci_priv)..."
    rm -f "$ci_priv" "$ci_pub"
    ssh-keygen -t ed25519 -N "" -f "$ci_priv" -C "nix-builder@yifuwuqi"
    chmod 0600 "$ci_priv"
    chmod 0644 "$ci_pub"
    chown -R "$target_user:$target_group" "$ci_dir"

    local ci_pub_content
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
}
