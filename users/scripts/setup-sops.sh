#!/usr/bin/env bash
set -euo pipefail

HOSTNAME=${1:-${HOST:-$(hostname)}}

if [ -z "$HOSTNAME" ]; then
    echo "Usage: $0 [hostname]"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "sudoing..."
  exec sudo "$0" "$HOSTNAME"
fi
USER_HOME=$(eval echo ~yi)
HOST_KEY="/persist/keys/ssh/ssh_host_ed25519_key"
MESH_KEY="$USER_HOME/.ssh/id_ed25519"
GIT_KEY="$USER_HOME/.ssh/id_git_ed25519"

echo "=<< setup for $HOSTNAME >>="

if [ ! -f "$HOST_KEY" ]; then
    echo "-> Generating Host Key..."
    mkdir -p "$(dirname "$HOST_KEY")"
    chmod 0700 "$(dirname "$HOST_KEY")"
    ssh-keygen -t ed25519 -N "" -f "$HOST_KEY" -C "root@$HOSTNAME"
else
    echo "-> host key ok"
fi

if [ ! -f "$MESH_KEY" ]; then
    echo "-> Generating Mesh Key..."
    sudo -u yi mkdir -p "$USER_HOME/.ssh"
    sudo -u yi chmod 700 "$USER_HOME/.ssh"
    sudo -u yi ssh-keygen -t ed25519 -N "" -f "$MESH_KEY" -C "yi@$HOSTNAME"
else
    echo "-> mesh key ok"
fi

# 3. Git Key
if [ ! -f "$GIT_KEY" ]; then
    echo "-> Generating Git Key..."
    sudo -u yi ssh-keygen -t ed25519 -N "" -f "$GIT_KEY" -C "yi@$HOSTNAME-git"
else
    echo "-> git Key ok"
fi

# We are running as root, so we can cat these files safely.
HOST_PUB=$(cat "$HOST_KEY.pub")
MESH_PUB=$(cat "$MESH_KEY.pub")
HOST_AGE=$(echo "$HOST_PUB" | sudo -u yi nix shell nixpkgs#ssh-to-age -c ssh-to-age)
MESH_AGE=$(echo "$MESH_PUB" | sudo -u yi nix shell nixpkgs#ssh-to-age -c ssh-to-age)

NEEDS_INSTRUCTIONS=false
if ! grep -Fq "$HOST_PUB" secrets/keys.nix 2>/dev/null; then
    NEEDS_INSTRUCTIONS=true
fi
if ! grep -Fq "$MESH_PUB" secrets/keys.nix 2>/dev/null; then
    NEEDS_INSTRUCTIONS=true
fi

if [ "$NEEDS_INSTRUCTIONS" = "true" ]; then
    echo "-> Converting public keys to age recipients..."

    echo ""
    echo "=========================================="
    echo "    Add to secrets/keys.nix (hosts)       "
    echo "=========================================="
    cat <<EOF
    $HOSTNAME = {
      sshPublicKey = "$HOST_PUB";
      ageRecipient = "$HOST_AGE";
    };
EOF

    echo ""
    echo "=========================================="
    echo "   Add to secrets/keys.nix (users.yi)     "
    echo "=========================================="
    cat <<EOF
      $HOSTNAME = {
        sshPublicKey = "$MESH_PUB";
        ageRecipient = "$MESH_AGE";
      };
EOF
fi

echo ""
echo "=========================================="
echo "                  keys                    "
echo "=========================================="
echo "-> host age:    $HOST_AGE"
echo "-> mesh age:    $MESH_AGE"
echo "-> host pkey:   $HOST_PUB"
echo "-> mesh pkey:   $MESH_PUB"
echo "-> git pkey:    $(cat "$GIT_KEY.pub")"
echo ""

echo "-> setup /persist/keys/sops permissions"
mkdir -p /persist/keys/sops
chown root:wheel /persist/keys/sops
chmod 0770 /persist/keys/sops
if [ -f /persist/keys/sops/secrets.yaml ]; then
    chown root:wheel /persist/keys/sops/secrets.yaml
    chmod 0660 /persist/keys/sops/secrets.yaml
fi

echo "-> generate .sops.yaml"
sudo -u yi nix eval --raw -f secrets/generate-sops-yaml.nix > .sops.yaml
chown yi .sops.yaml
