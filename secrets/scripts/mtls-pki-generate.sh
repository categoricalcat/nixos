#!/usr/bin/env bash
# Converge this host's mTLS material and, when this is the CA host, every
# peer's copy. This is the lane `nix run .#secrets` chains, so it runs before
# every switch and must be boring: mint what is missing, push only what
# differs, skip everything else.
#
#   mtls-pki-generate
#
# Only the registry's CA host (MTLS_CA_HOST) mints the CA, and only where a CA
# already exists or this host is that one. A peer that auto-minted its own
# would fork the trust anchor and split the mesh into two halves that reject
# each other, so an unseeded peer says which command seeds it and exits 0.
#
# MTLS_MESH, MTLS_CA_HOST and MTLS_SSH_PORT come from secrets/default.nix,
# generated from modules/addresses.nix. The same call concatenates the shared
# libs ahead of this file, so every variable here is assigned here.
set -euo pipefail
umask 077

d=/persist/keys/mtls
this=$(cat /proc/sys/kernel/hostname)
read -r -a meshEntries <<<"${MTLS_MESH:?run the wrapped build: nix shell .#secrets -c mtls-pki-generate}"

if [ "$EUID" -ne 0 ]; then
  echo "usage (as root): mtls-pki-generate" >&2
  exit 1
fi

if ! mtls_ip_of "$this" "${meshEntries[@]}" >/dev/null; then
  echo "-> $this has no mTLS role; nothing to do"
  exit 0
fi

# The CA host signs; a peer without the CA has nothing to sign with. Both mint
# their own pair; only the CA host can mint a peer's.
if [ ! -f "$d/service-ca.crt" ] && [ "$this" != "$MTLS_CA_HOST" ]; then
  echo "-> no service CA on this host yet. Seed this host by running, on"
  echo "   $MTLS_CA_HOST:"
  echo "   nix shell .#secrets -c mtls-pki-generate"
  exit 0
fi

mtls_prepare "$d"
[ -f "$d/service-ca.crt" ] || mtls_mint_ca "$d"
mtls_pair "$d" "$this" "${meshEntries[@]}"

if [ "$this" = "$MTLS_CA_HOST" ]; then
  # Every peer gets the CA cert plus its own pair; nobody ever reads a peer's
  # certificate, so nothing else travels. An unreachable peer already reported
  # itself; the loop continues so one absent host cannot block the rest.
  for entry in "${meshEntries[@]}"; do
    host=${entry%%:*}
    [ "$host" = "$this" ] && continue
    mtls_pair "$d" "$host" "${meshEntries[@]}"
    mtls_converge_peer "$MTLS_SSH_PORT" "$d" "$host" "${entry#*:}" || true
  done
fi

mtls_settle "$d" "$this" "${meshEntries[@]}"
echo
echo "-> $this holds:"
ls -l "$d"
