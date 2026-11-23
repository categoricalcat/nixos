#!/usr/bin/env bash
# Mint the name-constrained development CA and leaf in /persist/keys/dev/.
#
#   dev-certs-generate [domain ...]
#
# `domains` widens the CA's name constraints; localhost and yifuwuqi.lan are
# always included. There is no rotate: the CA key is discarded as soon as the
# leaf is signed, so renewing is running this again.
set -euo pipefail
umask 077

if [ "$EUID" -ne 0 ]; then
  echo "Usage (as root): dev-certs-generate [domain ...]" >&2
  exit 1
fi

# default.nix concatenates lib.sh ahead of this file for certs_leaf_ext.

d=/persist/keys/dev
dns=("$@" localhost yifuwuqi.lan)
permitted=$(printf 'permitted;DNS:%s,' "${dns[@]}")
sans=$(printf 'DNS:%s,' "${dns[@]}")

# The CA key lives only inside these substitutions: it is never written to
# disk, because the trust anchor it signs is worthless once the leaf exists.
cakey=$(openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256)
ca=$(openssl req -x509 -new -key <(printf '%s\n' "$cakey") -sha256 -days 3650 \
  -subj "/CN=aset dev CA" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -addext "nameConstraints=critical,${permitted}permitted;IP:127.0.0.0/255.0.0.0,permitted;IP:::1/ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff")

key=$(openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256)
cert=$(openssl x509 -new -sha256 -days 397 -subj "/CN=dev" \
  -force_pubkey <(openssl pkey -pubout <<<"$key") \
  -CA <(printf '%s\n' "$ca") -CAkey <(printf '%s\n' "$cakey") \
  -extfile <(certs_leaf_ext serverAuth "subjectAltName=${sans}IP:127.0.0.1,IP:::1"))
unset cakey

install -d -m 0755 -o root -g root "$d"
install -m 0644 -o root -g root /dev/stdin "$d/ca.pem" <<<"$ca"
install -m 0644 -o root -g root /dev/stdin "$d/cert.pem" <<<"$cert"
install -m 0640 -o root -g devcert /dev/stdin "$d/key.pem" <<<"$key"
unset key
jq -n --arg c "$(openssl x509 -outform DER <<<"$ca" | base64 -w0)" '{CACertificates: [$c]}' |
  install -m 0644 -o root -g root /dev/stdin "$d/chrome.json"
