# shellcheck shell=bash
# Sourced, never run. The two PKIs in this repo share exactly two things: the
# extension profile of a leaf certificate, and how material reaches a peer.
# Both live here so neither can drift.
#
#   certs_leaf_ext USAGE [SAN]   extension file for a server/client leaf
#   certs_push PORT DIR DIR-MODE DIR-GROUP MODE GROUP HOST... -- FILE...
#
# certs_push: PORT is empty for the default ssh port. Every FILE in one call
# shares MODE and GROUP. The directory is described separately because a caller
# may ship two ownerships into one directory (dev-certs: a root-owned leaf plus
# a devcert-readable key), and the directory must not depend on call order.

certs_leaf_ext() {
  printf 'basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=%s\n%s\n' "$1" "${2:-}"
}

# Run SCRIPT as root on HOST and print its stdout. PORT is empty for the
# default ssh port. Anything on stdin reaches the script.
#
# ssh joins its arguments with spaces and hands the result to the peer's login
# shell, which splits it again; an unquoted script would reach the peer as
# `bash -c set`, run nothing, and still exit 0. `%q` makes the script a single
# word so `bash -c` receives all of it. `-T` suppresses the "Pseudo-terminal
# will not be allocated" notice the fleet's `RequestTTY yes` prints otherwise,
# and ConnectTimeout keeps an absent peer from stalling the routine lane.
certs_run() {
  local port=$1 host=$2 script=$3 quoted
  printf -v quoted '%q' "$script"
  local -a sshOpts=(-o BatchMode=yes -o ConnectTimeout=5 -T)
  [ "$port" = "" ] || sshOpts+=(-p "$port")
  ssh "${sshOpts[@]}" "root@$host" bash -c "$quoted"
}

certs_push() {
  local port=$1 dir=$2 dirMode=$3 dirGroup=$4 mode=$5 group=$6
  shift 6

  local -a hosts=()
  while [ "${1:-}" != "--" ]; do
    hosts+=("$1")
    shift
  done
  shift

  if [ "${#hosts[@]}" -eq 0 ] || [ "$#" -eq 0 ]; then
    echo "certs_push: need at least one host and one file" >&2
    return 1
  fi

  # Space-separated absolute paths for the arrival step: the leading space
  # keeps them off the owner (`root:g /dir/a /dir/b`), and each name must be
  # expanded or `chown` reads the second as another owner.
  local paths="" name
  for name in "$@"; do
    paths+=" $dir/$name"
  done

  local host out
  for host in "${hosts[@]}"; do
    echo "-> pushing $* to $host:$dir"
    # groupadd is idempotent, and the peer may not have deployed the generation
    # that declares the group yet. Owner and mode are re-applied rather than
    # trusted from the archive: tar restores gids numerically, and
    # `groupadd --system` can give the same group name a different gid.
    #
    # The remote script is built here in full, so every value below expands
    # locally; the peer only runs the finished text as a program. The sentinel
    # is the only proof it ran: a shell that executed just `set` exits 0 too.
    # The match is unanchored because a login banner may prepend lines.
    local remote="set -e
        getent group $group >/dev/null || groupadd --system $group
        getent group $dirGroup >/dev/null || groupadd --system $dirGroup
        install -d -m $dirMode -o root -g $dirGroup $dir
        tar -C $dir -xf -
        chown root:$group$paths
        chmod $mode$paths
        printf 'certs-push-ok\n'"
    if ! out=$(tar -C "$dir" -cf - -- "$@" | certs_run "$port" "$host" "$remote"); then
      echo "certs_push: push to $host failed (tar, transport or arrival step)" >&2
      return 1
    fi
    case $out in
    *certs-push-ok*) ;;
    *)
      echo "certs_push: $host never ran the arrival script; nothing arrived" >&2
      return 1
      ;;
    esac
  done
}
