#!/usr/bin/env bash
# Host SSH & Age Key Management
# Migrates /etc/ssh host key if present, otherwise generates a fresh ed25519 key.

ensure_host_key() {
  local key_path="$1"
  local hostname="$2"
  local key_dir
  key_dir="$(dirname "$key_path")"

  mkdir -p "$key_dir"
  if [ ! -f "$key_path" ]; then
    if [ -f "/etc/ssh/ssh_host_ed25519_key" ]; then
      echo "-> Migrating existing Host Key from /etc/ssh..."
      cp -a /etc/ssh/ssh_host_ed25519_key "$key_path"
      cp -a /etc/ssh/ssh_host_ed25519_key.pub "$key_path.pub"
    else
      echo "-> Generating Host Key..."
      ssh-keygen -t ed25519 -N "" -f "$key_path" -C "root@$hostname"
    fi
  else
    echo "-> host key ok"
  fi

  if [ -f "$key_path" ] && [ ! -f "$key_path.pub" ]; then
    echo "-> Deriving missing host public key..."
    ssh-keygen -y -f "$key_path" >"$key_path.pub"
  fi

  chown root:root "$key_dir" "$key_path" "$key_path.pub"
  chmod 0700 "$key_dir"
  chmod 0600 "$key_path"
  chmod 0644 "$key_path.pub"
}
