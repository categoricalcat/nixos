#!/usr/bin/env bash
# Convert an SSH public key to an age recipient string via ssh-to-age.

ssh_pub_to_age() {
  local pub="$1"
  if command -v ssh-to-age >/dev/null 2>&1; then
    echo "$pub" | ssh-to-age
  else
    echo "$pub" | runuser -u yi -- env HOME=/home/yi nix shell "nixpkgs#ssh-to-age" -c ssh-to-age
  fi
}
