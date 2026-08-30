#!/usr/bin/env bash
# User SSH Key Management
# Generates and enforces permissions for persistent user SSH keys.

ensure_user_key() {
  local user="$1"
  local group="$2"
  local key_path="$3"
  local comment="$4"
  local key_dir
  key_dir="$(dirname "$key_path")"

  runuser -u "$user" -- mkdir -p "$key_dir"

  if [ ! -f "$key_path" ]; then
    echo "-> Generating $(basename "$key_path")..."
    runuser -u "$user" -- ssh-keygen -t ed25519 -N "" -f "$key_path" -C "$comment"
  else
    echo "-> $(basename "$key_path") ok"
  fi

  if [ -f "$key_path" ] && [ ! -f "$key_path.pub" ]; then
    echo "-> Deriving missing $(basename "$key_path") public key..."
    runuser -u "$user" -- ssh-keygen -y -f "$key_path" >"$key_path.pub"
  fi

  chown "$user:$group" "$key_path"
  chmod 0600 "$key_path"
  if [ -f "$key_path.pub" ]; then
    chown "$user:$group" "$key_path.pub"
    chmod 0644 "$key_path.pub"
  fi
}
