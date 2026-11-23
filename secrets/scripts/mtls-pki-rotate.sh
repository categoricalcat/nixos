#!/usr/bin/env bash
# Re-sign one host's mTLS pair against the existing CA, defaulting to this
# host, and push it to that host afterwards. Needs the CA key, so it only works
# on the CA host: a peer cannot renew anything, which is why it says so instead
# of destroying a working pair it could not re-sign.
#
#   mtls-pki-rotate [host]
#
# Quiet when this host has no mTLS role or no CA yet: failing there would break
# the `nix run .#secrets` lane that chains these.
#
# MTLS_MESH, MTLS_CA_HOST and MTLS_SSH_PORT come from secrets/default.nix,
# generated from modules/addresses.nix. The same call concatenates the shared
# libs ahead of this file, so every variable here is assigned here.
set -euo pipefail
umask 077

d=/persist/keys/mtls
this=$(cat /proc/sys/kernel/hostname)
read -r -a meshEntries <<<"${MTLS_MESH:?run the wrapped build: nix shell .#secrets -c mtls-pki-rotate}"

if [ "$EUID" -ne 0 ]; then
  echo "usage (as root): mtls-pki-rotate [host]" >&2
  exit 1
fi
if [ "$#" -gt 1 ]; then
  echo "usage: mtls-pki-rotate [host]" >&2
  exit 1
fi

target=${1:-$this}

if ! mtls_ip_of "$this" "${meshEntries[@]}" >/dev/null; then
  echo "-> $this has no mTLS role; nothing to do"
  exit 0
fi
if [ ! -f "$d/service-ca.crt" ]; then
  echo "-> no service CA on this host; nothing to rotate. Seed the mesh from"
  echo "   $MTLS_CA_HOST with mtls-pki-generate."
  exit 0
fi

ip=$(mtls_ip_of "$target" "${meshEntries[@]}") || {
  echo "-> unknown host $target: not in the mTLS mesh (modules/addresses.nix)" >&2
  exit 1
}

mtls_prepare "$d"
mtls_require_signer "$d" "rotate $target"
mtls_drop_pair "$d" "$target"
mtls_pair "$d" "$target" "${meshEntries[@]}"

# A peer's new pair is only useful on the peer; its own generation restarts
# nginx on the next switch. Unreachable is a warning, not a rollback: the pair
# here is already re-signed and converges on the next routine run.
if [ "$target" != "$this" ]; then
  mtls_converge_peer "$MTLS_SSH_PORT" "$d" "$target" "$ip" ||
    echo "-> warning: $target did not take the push; re-run after fixing access" >&2
fi

mtls_settle "$d" "$this" "${meshEntries[@]}"
echo
echo "-> $this holds:"
ls -l "$d"
