#!/usr/bin/env bash

set -euo pipefail

echo "=== SOPS & SSH Host Key Setup ==="

# Check for root/sudo
if [ "$EUID" -ne 0 ]; then
  echo "Elevating privileges to create directories and manage keys..."
  exec sudo "$0" "$@"
fi

echo "1. Creating /persist/keys directories..."
install -d -m 0700 -o root -g root /persist/keys/ssh
install -d -m 0750 -o root -g root /persist/keys/sops

echo "2. Checking for existing SSH host identity..."
if [ -f "/persist/keys/ssh/ssh_host_ed25519_key" ]; then
    echo " -> Found existing identity in /persist/keys/ssh/"
else
    if [ -f "/etc/ssh/ssh_host_ed25519_key" ]; then
        echo " -> Found existing identity in /etc/ssh/. Copying to preserve fingerprint..."
        install -m 0600 -o root -g root /etc/ssh/ssh_host_ed25519_key /persist/keys/ssh/ssh_host_ed25519_key
    else
        echo " -> No existing identity found. Generating new ed25519 host key..."
        ssh-keygen -t ed25519 -N '' -f /persist/keys/ssh/ssh_host_ed25519_key
    fi
fi

echo "3. Extracting public key..."
ssh-keygen -y -f /persist/keys/ssh/ssh_host_ed25519_key > /persist/keys/ssh/ssh_host_ed25519_key.pub
chown root:root /persist/keys/ssh/ssh_host_ed25519_key.pub
chmod 0644 /persist/keys/ssh/ssh_host_ed25519_key.pub

PUB_KEY=$(cat /persist/keys/ssh/ssh_host_ed25519_key.pub)

echo "4. Deriving age recipient..."
if ! command -v ssh-to-age &> /dev/null; then
    echo " -> ssh-to-age not found, using nix run..."
    AGE_RECIPIENT=$(nix run nixpkgs#ssh-to-age -- -i /persist/keys/ssh/ssh_host_ed25519_key.pub)
else
    AGE_RECIPIENT=$(ssh-to-age -i /persist/keys/ssh/ssh_host_ed25519_key.pub)
fi

echo ""
echo "=================================================="
echo "SUCCESS: Host keys generated/configured."
echo "=================================================="
echo ""
echo "Next steps: "
echo ""
echo "1. Add the following to your host entry in secrets/keys.nix:"
echo ""
echo "      sshPublicKey = \"$PUB_KEY\";"
echo "      ageRecipient = \"$AGE_RECIPIENT\";"
echo ""
echo "2. Add the age recipient to the appropriate creation_rules in .sops.yaml:"
echo ""
echo "          - $AGE_RECIPIENT"
echo ""
echo "3. Rekey your secrets (using the legacy key if this host isn't switched yet, or the new key if it is):"
echo ""
echo "   SOPS_AGE_KEY_FILE=/etc/nixos/secrets/key.txt nix-shell -p sops --run 'sops updatekeys -y secrets/secrets.yaml'"
echo "   # OR"
echo "   SOPS_AGE_SSH_PRIVATE_KEY_FILE=/persist/keys/ssh/ssh_host_ed25519_key nix-shell -p sops --run 'sops updatekeys -y secrets/secrets.yaml'"
echo ""
echo "4. Install the encrypted payload on this host (if needed):"
echo ""
echo "   sudo install -m 0640 -o root -g root secrets/secrets.yaml /persist/keys/sops/secrets.yaml"
echo ""
