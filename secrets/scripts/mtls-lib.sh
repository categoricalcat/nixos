# shellcheck shell=bash
# Everything the mtls-pki commands share. Functions only, with explicit
# parameters and no globals: secrets/default.nix concatenates this file ahead of
# each command, and a lib that reads variables it never assigns would leave the
# linter unable to verify either half on its own.
#
# MTLS_MESH, MTLS_CA_HOST and MTLS_SSH_PORT are injected by secrets/default.nix,
# generated from modules/addresses.nix, so the SANs cannot desync from the
# registry and no script restates a host name.

# Print the LAN address of NAME from the mesh entries NAME:IP...
mtls_ip_of() {
  local name=$1
  shift
  local entry
  for entry in "$@"; do
    if [ "${entry%%:*}" = "$name" ]; then
      echo "${entry#*:}"
      return 0
    fi
  done
  return 1
}

# The group may predate the generation that declares it, and activation adopts
# a pre-existing one by name, so create it here rather than assuming a deploy.
mtls_prepare() {
  groupadd --system mtls 2>/dev/null || true
  install -d -m 0750 -o root -g mtls "$1"
  cd "$1" || exit 1
}

# The CA is minted by the one host the registry names, never by whoever happens
# to run the command first: a second host minting its own would fork the trust
# anchor and silently split the mesh into two halves that reject each other.
mtls_mint_ca() {
  local dir=$1
  if [ -f "$dir/service-ca.key" ]; then
    echo "service-ca.key exists without its certificate: refusing to overwrite" >&2
    echo "the key and orphan every leaf it signed. Restore service-ca.crt, or" >&2
    echo "remove both and re-seed." >&2
    exit 1
  fi
  echo "-> minting the internal CA (10 years)"
  openssl ecparam -name secp384r1 -genkey -noout -out "$dir/service-ca.key"
  openssl req -new -x509 -sha384 -key "$dir/service-ca.key" -out "$dir/service-ca.crt" -days 3650 \
    -subj "/CN=Aset Internal Service CA" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign"
}

# A peer holds the CA certificate but never its key, so it cannot sign. Say so
# in words the operator can act on instead of failing inside openssl. LABEL is
# the verb phrase: "mint yifuwuqi-server", "rotate on yirukou".
mtls_require_signer() {
  if [ ! -f "$1/service-ca.key" ]; then
    echo "-> cannot $2: service-ca.key is not on this host." >&2
    echo "   Run it on ${MTLS_CA_HOST} instead; the result reaches peers by push." >&2
    exit 1
  fi
}

# Drop a pair so the next mint re-signs it.
mtls_drop_pair() {
  local dir=$1 host=$2
  rm -f "$dir/$host-server.crt" "$dir/$host-server.key" \
    "$dir/$host-client.crt" "$dir/$host-client.key"
}

# Mint one leaf if absent. `x509 -new -force_pubkey` signs the key just
# generated, so no CSR touches disk.
mtls_leaf() {
  local dir=$1 name=$2 usage=$3 san=$4
  if [ -f "$dir/$name.crt" ] && [ -f "$dir/$name.key" ]; then
    return
  fi
  mtls_require_signer "$dir" "mint $name"
  echo "-> signing $name"
  openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:secp384r1 -out "$dir/$name.key"
  openssl x509 -new -sha384 -days 1095 -subj "/CN=$name" \
    -force_pubkey <(openssl pkey -pubout -in "$dir/$name.key") \
    -CA "$dir/service-ca.crt" -CAkey "$dir/service-ca.key" \
    -extfile <(certs_leaf_ext "$usage" "$san") -out "$dir/$name.crt"
}

# Both leaves for one host, resolving its SAN from the mesh entries.
mtls_pair() {
  local dir=$1 host=$2
  shift 2
  local ip
  ip=$(mtls_ip_of "$host" "$@") || {
    echo "unknown host $host: not in the mTLS mesh (modules/addresses.nix)" >&2
    exit 1
  }
  mtls_leaf "$dir" "$host-server" serverAuth "subjectAltName=DNS:$host.lan,IP:$ip"
  mtls_leaf "$dir" "$host-client" clientAuth ""
}

# One digest per file, `-` for a missing one. Comparing a peer's copy needs
# keys as well as certificates: a peer whose key vanished but whose certificate
# survived would otherwise look current.
mtls_digest() {
  local dir=$1 f
  shift
  for f in "$@"; do
    if [ -f "$dir/$f" ]; then
      sha256sum "$dir/$f" | cut -d' ' -f1
    else
      echo -
    fi
  done
}

# The same digests read from a peer, in one ssh round trip. Empty on failure so
# a caller can tell "unreachable" from "differs".
mtls_peer_digest() {
  local port=$1 host=$2 dir=$3
  shift 3
  local paths="" f
  for f in "$@"; do
    paths+=" $dir/$f"
  done
  certs_run "$port" "$host" "for f in$paths; do
        if [ -f \"\$f\" ]; then sha256sum \"\$f\" | cut -d' ' -f1; else echo -; fi
      done"
}

# Make one peer's copy match ours, pushing only when it differs. A peer that is
# merely unreachable or not yet keyed is a warning, not a failure: the routine
# lane runs before every switch, and this host's own material is what its
# services need. A push that starts and fails is still fatal, because that
# leaves a half-written set on the peer.
mtls_converge_peer() {
  local port=$1 dir=$2 host=$3 ip=$4
  shift 4
  local -a files=(
    "$host-server.crt" "$host-server.key"
    "$host-client.crt" "$host-client.key" service-ca.crt
  )
  local want got
  want=$(mtls_digest "$dir" "${files[@]}")
  if got=$(mtls_peer_digest "$port" "$ip" "$dir" "${files[@]}") && [ "$got" = "$want" ]; then
    echo "-> $host ok"
    return 0
  fi
  if [ "${got-}" = "" ]; then
    echo "-> warning: $host unreachable or not seeded; it keeps stale certificates" >&2
    return 1
  fi
  certs_push "$port" "$dir" 0750 mtls 0640 mtls "$ip" -- "${files[@]}"
}

# Modes and ownership, applied to whatever this run left on disk. The CA key
# never belongs in a group-readable ACL; the served material does. THIS_HOST is
# the only host whose leaves are served here, so a peer's pair (kept by the CA
# host to make the push idempotent) stays root-only.
mtls_settle() {
  local dir=$1 thisHost=$2
  shift 2
  local entry host f
  local -a served=("$dir/service-ca.crt")
  if [ -f "$dir/service-ca.key" ]; then
    chown root:root "$dir/service-ca.key"
    chmod 0600 "$dir/service-ca.key"
  fi
  for f in "$dir/$thisHost-server.crt" "$dir/$thisHost-server.key" \
    "$dir/$thisHost-client.crt" "$dir/$thisHost-client.key"; do
    [ -f "$f" ] && served+=("$f")
  done
  chown root:mtls "${served[@]}"
  chmod 0640 "${served[@]}"
  for entry in "$@"; do
    host=${entry%%:*}
    [ "$host" = "$thisHost" ] && continue
    for f in "$dir/$host-server.crt" "$dir/$host-server.key" \
      "$dir/$host-client.crt" "$dir/$host-client.key"; do
      [ -f "$f" ] || continue
      chown root:root "$f"
      chmod 0600 "$f"
    done
  done
}
