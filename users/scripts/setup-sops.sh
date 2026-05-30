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
HOST_KEY_DIR="$(dirname "$HOST_KEY")"
MESH_KEY="$USER_HOME/.ssh/id_ed25519"
GIT_KEY="$USER_HOME/.ssh/id_git_ed25519"

echo "=<< setup for $HOSTNAME >>="

mkdir -p "$HOST_KEY_DIR"
if [ ! -f "$HOST_KEY" ]; then
    if [ -f "/etc/ssh/ssh_host_ed25519_key" ]; then
        echo "-> Migrating existing Host Key from /etc/ssh..."
        cp -a /etc/ssh/ssh_host_ed25519_key "$HOST_KEY"
        cp -a /etc/ssh/ssh_host_ed25519_key.pub "$HOST_KEY.pub"
    else
        echo "-> Generating Host Key..."
        ssh-keygen -t ed25519 -N "" -f "$HOST_KEY" -C "root@$HOSTNAME"
    fi
else
    echo "-> host key ok"
fi

if [ -f "$HOST_KEY" ] && [ ! -f "$HOST_KEY.pub" ]; then
    echo "-> Deriving missing host public key..."
    ssh-keygen -y -f "$HOST_KEY" > "$HOST_KEY.pub"
fi

chown root:root "$HOST_KEY_DIR" "$HOST_KEY" "$HOST_KEY.pub"
chmod 0700 "$HOST_KEY_DIR"
chmod 0600 "$HOST_KEY"
chmod 0644 "$HOST_KEY.pub"

sudo -u yi mkdir -p "$USER_HOME/.ssh"

if [ ! -f "$MESH_KEY" ]; then
    echo "-> Generating Mesh Key..."
    sudo -u yi ssh-keygen -t ed25519 -N "" -f "$MESH_KEY" -C "yi@$HOSTNAME"
else
    echo "-> mesh key ok"
fi

if [ ! -f "$GIT_KEY" ]; then
    echo "-> Generating Git Key..."
    sudo -u yi ssh-keygen -t ed25519 -N "" -f "$GIT_KEY" -C "yi@$HOSTNAME-git"
else
    echo "-> git Key ok"
fi

chown yi:yi "$USER_HOME/.ssh"
chmod 0700 "$USER_HOME/.ssh"
for key in "$MESH_KEY" "$GIT_KEY"; do
    if [ -f "$key" ]; then
        chown yi:yi "$key"
        chmod 0600 "$key"
    fi
    if [ -f "$key.pub" ]; then
        chown yi:yi "$key.pub"
        chmod 0644 "$key.pub"
    fi
done

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
mkdir -p /persist/keys
chown root:root /persist/keys
chmod 0755 /persist/keys
mkdir -p /persist/keys/sops
chown root:wheel /persist/keys/sops
chmod 0770 /persist/keys/sops

echo "-> syncing secrets to /persist/keys/sops/secrets.yaml"
if [ -f "secrets/secrets.yaml" ] && [ ! -f "/persist/keys/sops/secrets.yaml" ]; then
    cp secrets/secrets.yaml /persist/keys/sops/secrets.yaml
fi

if [ -f /persist/keys/sops/secrets.yaml ]; then
    chown root:wheel /persist/keys/sops/secrets.yaml
    chmod 0660 /persist/keys/sops/secrets.yaml
fi

if [ -f /persist/keys/sops/key.txt ]; then
    chown root:root /persist/keys/sops/key.txt
    chmod 0600 /persist/keys/sops/key.txt
fi

echo "-> generate .sops.yaml"
sudo -u yi nix eval --raw -f secrets/generate-sops-yaml.nix > .sops.yaml
chown yi .sops.yaml
