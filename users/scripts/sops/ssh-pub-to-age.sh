#!/usr/bin/env bash
# Convert an SSH public key to an age recipient string via ssh-to-age.

ssh_pub_to_age() {
  local pub="$1"
  echo "$pub" | runuser -u yi -- nix shell "nixpkgs#ssh-to-age" -c ssh-to-age
}
