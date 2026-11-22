#!/usr/bin/env bash
# Convert an SSH public key to an age recipient string via ssh-to-age.
# usage: ssh-pub-to-age <ssh-public-key>
set -euo pipefail

echo "$1" | ssh-to-age
