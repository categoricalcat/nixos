#!/usr/bin/env bash
# ai-gate behavior matrix: freezes the gate's dispatch table (protocol, deny
# rules, path allowlist) before any fix — findings it exposes get fixed in a
# separate change, never in the same diff as these tests.
#
# Deny cases must exit 1 with the expected "ai-gate: denied: ..." reason;
# allow cases must reach the stub binary with the expected argv. Stubs print
# "cmd: args".
#
# usage: ai-gate-test.sh <gate-script> [sandbox-dir]
set -euo pipefail

# The gate's unquoted DENIED_PATTERNS glob at array-definition time: from a
# cwd with matching files (e.g. the repo's secrets/) they expand into file
# lists and the deny rules die. Pin a clean cwd and patch BIN= on a sandbox
# copy so production ai-gate.sh keeps an immutable BIN path.
gate_src=$(realpath "$1")
if [ "${2:-}" = "" ]; then
  sandbox=$(mktemp -d)
  trap 'rm -rf "${sandbox:?}"' EXIT
else
  sandbox=$(realpath -m "$2")
fi
bin=$sandbox/bin
gate=$sandbox/ai-gate.sh
mkdir -p "$bin"
grep -q '^BIN=' "$gate_src" || {
  printf 'FAIL: %s has no BIN= assignment to patch\n' "$gate_src" >&2
  exit 1
}
sed "s|^BIN=.*|BIN=$bin|" "$gate_src" >"$gate"
cd "$sandbox"

# realpath and base64 are gate-internal tools; dispatch targets are stubs.
ln -s "$(command -v realpath)" "$bin/realpath"
ln -s "$(command -v base64)" "$bin/base64"

mk_stub() {
  # /bin/sh: the Nix build sandbox has no /usr/bin/env; POSIX printf suffices.
  cat >"$bin/$1" <<STUB
#!/bin/sh
printf '%s: %s\n' '$1' "\$*"
STUB
  chmod +x "$bin/$1"
}
for cmd in hostname ip networkctl ping systemctl journalctl cat ls readlink; do
  mk_stub "$cmd"
done

b64() { printf '%s' "$1" | base64 | tr -d '\n'; }

gate_out=""
gate_rc=0

run_gate() {
  gate_rc=0
  gate_out=$(bash "$gate" "$@" 2>&1) || gate_rc=$?
}

run_gate_proto() {
  gate_rc=0
  gate_out=$(SSH_ORIGINAL_COMMAND="$1" bash "$gate" 2>&1) || gate_rc=$?
}

expect_deny() {
  local desc=$1 reason=$2
  shift 2
  run_gate "$@"
  check_deny "$desc" "$reason"
}

expect_deny_proto() {
  run_gate_proto "$3"
  check_deny "$1" "$2"
}

check_deny() {
  if [ "$gate_rc" -eq 1 ] && [[ "$gate_out" == *"ai-gate: denied:"*"$2"* ]]; then
    printf 'ok (deny): %s\n' "$1"
  else
    printf 'FAIL (deny): %s: rc=%s out=%s expected=%s\n' "$1" "$gate_rc" "$gate_out" "$2" >&2
    exit 1
  fi
}

expect_allow() {
  local desc=$1 expected=$2
  shift 2
  run_gate "$@"
  check_allow "$desc" "$expected"
}

expect_allow_proto() {
  run_gate_proto "$3"
  check_allow "$1" "$2"
}

check_allow() {
  if [ "$gate_rc" -eq 0 ] && [ "$gate_out" = "$2" ]; then
    printf 'ok (allow): %s\n' "$1"
  else
    printf 'FAIL (allow): %s: rc=%s out=%s expected=%s\n' "$1" "$gate_rc" "$gate_out" "$2" >&2
    exit 1
  fi
}

# --- protocol edge cases -----------------------------------------------------
expect_deny_proto "empty SSH_ORIGINAL_COMMAND" "no command provided" ""
expect_deny_proto "protocol version only, no args" "empty command" "v1"
expect_deny_proto "unrecognized protocol version" "unrecognized command protocol" "v2 $(b64 hostname)"
expect_deny_proto "invalid base64 token" "bad argument encoding" "v1 !!!"
expect_allow_proto "single-token dispatch" "hostname: " "v1 $(b64 hostname)"
expect_allow_proto "multi-argument dispatch" "ip: addr show" "v1 $(b64 ip) $(b64 addr) $(b64 show)"
expect_allow_proto "base64 preserves metacharacters without eval" 'journalctl: --no-pager -g a; $(id)' "v1 $(b64 journalctl) $(b64 -g) $(b64 'a; $(id)')"

# --- deny cases ---------------------------------------------------------------
expect_deny "unknown command" "unknown command" curl "https://example.com"
expect_deny "ip write action (addr add)" "write action not allowed" ip addr add 10.0.0.1/24 dev lo
expect_deny "ip write action (link set)" "write action not allowed" ip link set dev lo up
expect_deny "ip write action (route add)" "write action not allowed" ip route add 10.9.9.9 via 10.42.0.1
expect_deny "ip bad subcommand" "bad subcommand" ip flush dev lo
expect_deny "networkctl reconfigure" "bad subcommand" networkctl reconfigure eno1
expect_deny "systemctl start" "bad subcommand" systemctl start nginx.service
expect_deny "systemctl reboot" "bad subcommand" systemctl reboot
expect_deny "journalctl -f" "follow is not allowed" journalctl -f
expect_deny "journalctl --follow" "follow is not allowed" journalctl --follow
expect_deny "journalctl short-option cluster" "follow is not allowed" journalctl -fu sshd
expect_deny "journalctl --follow=..." "follow is not allowed" journalctl --follow=short
expect_deny "journalctl trailing -f" "follow is not allowed" journalctl -u sshd -f

# Protected patterns: every path sits under an ALLOWED_ROOT (/etc or /run) so
# each DENIED_PATTERNS rule is exercised rather than falling through to
# ALLOWED_ROOTS.
expect_deny "cat protected secrets path" "path is protected/secret" cat /etc/secrets/secret.yaml
expect_deny "cat protected keys path" "path is protected/secret" cat /run/keys/something
expect_deny "cat ssh identity" "path is protected/secret" cat /run/id_ed25519
expect_deny "cat ssh host key" "path is protected/secret" cat /etc/ssh/ssh_host_ed25519_key
expect_deny "cat ssh config" "path is protected/secret" cat /etc/.ssh/config

# Traversal, separator, and allowlist boundaries
expect_deny "cat .. traversal to protected key" "path is protected/secret" cat /etc/../persist/keys/age.txt
expect_deny "cat .. traversal outside allowlist" "path outside allowlist" cat /etc/../home/yi/notes.txt
expect_deny "cat -- before protected path" "path is protected/secret" cat -- /etc/secrets/x
expect_deny "cat outside allowlist" "path outside allowlist" cat /home/yi/notes.txt
expect_deny "cat relative path" "path not absolute" cat relative.txt
expect_deny "cat mixed allowed and denied" "path outside allowlist" cat /etc/hostname /home/yi/notes.txt
expect_deny "ls outside allowlist" "path outside allowlist" ls /root
expect_deny "readlink outside allowlist" "path outside allowlist" readlink /var/lib/private

# --- allow cases --------------------------------------------------------------
expect_allow "hostname" "hostname: " hostname
expect_allow "ip addr show" "ip: addr show" ip addr show
expect_allow "ip flags pass through" "ip: -j route show" ip -j route show
expect_allow "ip bare subcommand" "ip: route" ip route
expect_allow "networkctl status" "networkctl: status" networkctl status
expect_allow "ping" "ping: 10.42.0.1" ping 10.42.0.1
# Finding (frozen, fix separately): ping flags are unrestricted.
expect_allow "ping with flags" "ping: -c1 -W2 10.42.0.1" ping -c1 -W2 10.42.0.1
expect_allow "systemctl status" "systemctl: status nginx" systemctl status nginx
expect_allow "journalctl prepends --no-pager" "journalctl: --no-pager -u sshd -n 50" journalctl -u sshd -n 50
expect_allow "cat allowed path" "cat: /etc/hostname" cat /etc/hostname
expect_allow "cat multiple allowed paths" "cat: /etc/hostname /proc/version" cat /etc/hostname /proc/version
expect_allow "ls store path" "ls: /nix/store" ls /nix/store
expect_allow "readlink run path" "readlink: /run/current-system" readlink /run/current-system

printf 'ai-gate: all matrix cases passed\n'
