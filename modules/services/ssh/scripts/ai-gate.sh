#!/usr/bin/env bash
set -euo pipefail

BIN=/run/current-system/sw/bin

# Read-only gate for the `ai` user. Dispatch on the first argument, pass the
# remaining args verbatim via "$@" (no eval). A hostile key can only run the
# whitelisted reads below; everything else is rejected.
#
# Whitelisted: systemctl (status/is-active/is-failed/is-enabled/show/list-*),
# journalctl (read-only flags, no -f), and cat/ls/readlink over the path
# allowlist.

# Path roots read-only commands may touch. Extend per host if needed.
ALLOWED_ROOTS=(/etc /proc /var/log /nix/var/nix/profiles /nix/store /run/current-system)

deny() {
  echo "ai-gate: denied: $*" >&2
  exit 1
}

path_ok() {
  local p="$1" rp root
  case "$p" in
    /*) ;;
    *) deny "path not absolute: $p" ;;
  esac
  rp=$($BIN/realpath -m "$p")
  for root in "${ALLOWED_ROOTS[@]}"; do
    case "$rp" in
      "$root" | "$root"/*) return 0 ;;
    esac
  done
  deny "path outside allowlist: $p"
}

# Reconstruct argv from the ai-ssh protocol: "v1" then one base64 token per
# argument. Tokens are base64 (no whitespace) so word-splitting is safe, and
# each is decoded verbatim (no eval), preserving spaces/quotes.
if [ "$#" -eq 0 ]; then
  if [ -z "${SSH_ORIGINAL_COMMAND:-}" ]; then
    deny "no command provided"
  fi
  read -r -a TOK <<< "$SSH_ORIGINAL_COMMAND"
  if [ "${TOK[0]:-}" != "v1" ]; then
    deny "unrecognized command protocol"
  fi
  ARGS=()
  for t in "${TOK[@]:1}"; do
    d=$(printf '%s' "$t" | $BIN/base64 -d 2>/dev/null) || deny "bad argument encoding"
    ARGS+=("$d")
  done
  if [ "${#ARGS[@]}" -eq 0 ]; then
    deny "empty command"
  fi
  set -- "${ARGS[@]}"
fi

case "${1:-}" in
  systemctl)
    shift
    case "${1:-}" in
      status | is-active | is-failed | is-enabled | show | list-units | list-timers | list-sockets)
        exec "$BIN/systemctl" "$@"
        ;;
      *) deny "systemctl: bad subcommand: ${1:-}" ;;
    esac
    ;;
  journalctl)
    shift
    # Reject follow in every form: --follow, --follow=..., and any short-option
    # cluster containing f (-f, -fu, -uf).
    for a in "$@"; do
      case "$a" in
        --follow | --follow=*) deny "journalctl: follow is not allowed" ;;
        --*) : ;;
        -*f*) deny "journalctl: follow is not allowed" ;;
      esac
    done
    exec "$BIN/journalctl" --no-pager "$@"
    ;;
  cat | ls | readlink)
    cmd="$1"
    shift
    for a in "$@"; do
      case "$a" in
        -*) : ;;
        *) path_ok "$a" ;;
      esac
    done
    exec "$BIN/$cmd" "$@"
    ;;
  *)
    deny "unknown command: ${1:-}"
    ;;
esac
