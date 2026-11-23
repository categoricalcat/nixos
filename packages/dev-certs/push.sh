#!/usr/bin/env bash
# Hand the current dev certificates to peers.
#
#   dev-certs-push <host...>
#
# Each peer receives the same four files. Two calls because the leaf key is
# group-readable for devcert while the rest is world-readable; the directory
# itself stays root-owned either way.
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Usage (as root): dev-certs-push <host...>" >&2
  exit 1
fi

if [ "$#" -eq 0 ]; then
  echo "usage: dev-certs-push <host...>" >&2
  exit 1
fi

# SSH_PORT and lib.sh are prepended by default.nix: a store path cannot locate
# its siblings, and the fleet's sshd port comes from the registry.
d=/persist/keys/dev
certs_push "$SSH_PORT" "$d" 0755 root 0644 root "$@" -- ca.pem cert.pem chrome.json
certs_push "$SSH_PORT" "$d" 0755 root 0640 devcert "$@" -- key.pem
