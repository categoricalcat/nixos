#!/usr/bin/env bash
set -euo pipefail

# Textfile collector directory for node_exporter
TEXTFILE_DIR="${1:-/var/lib/prometheus-node-exporter/textfile}"
# Container identities JSON rendered from config at evaluation time
IDENTITIES="${2:-}"
mkdir -p "$TEXTFILE_DIR"

TMP_FILE="$TEXTFILE_DIR/security_fast.prom.$$"
trap 'rm -f "$TMP_FILE"' EXIT

# 1. Detect kernel and module mismatch requiring reboot
check_reboot_required() {
  local bk ck bm cm
  bk=$(readlink -f /run/booted-system/kernel 2>/dev/null || true)
  ck=$(readlink -f /run/current-system/kernel 2>/dev/null || true)
  bm=$(readlink -f /run/booted-system/kernel-modules 2>/dev/null || true)
  cm=$(readlink -f /run/current-system/kernel-modules 2>/dev/null || true)

  if [[ -n $bk && -n $ck && ($bk != "$ck" || $bm != "$cm") ]]; then
    echo 1
  else
    echo 0
  fi
}

# 2. System generation age (seconds since activation)
get_generation_age() {
  local now="$1" gen_time
  gen_time=$(stat -c %Y /nix/var/nix/profiles/system 2>/dev/null || stat -c %Y /run/current-system 2>/dev/null || echo "$now")
  echo $((now - gen_time))
}

# 3. Numeric IDs appearing more than once in the account database
count_duplicate_ids() {
  cut -d: -f3 "$1" | sort | uniq -d | wc -l
}

account_name() {
  awk -F: -v id="$1" '$3 == id {print $1; exit}' /etc/passwd
}

group_name() {
  awk -F: -v id="$1" '$3 == id {print $1; exit}' /etc/group
}

# 4. Container identity audit. Container processes live in
# /machine.slice/libpod-<ctr-id>.scope; <ctr-id> maps to the declared container
# name via /run/<name>/ctr-id (conmon stays in the podman-<name>.service cgroup
# and is therefore excluded). Arg 1: identities JSON rendered from config
# ({<name>: {duid: <num|null>, dgid: <num|null>, rootReason: <str|null>}}). A
# process reports container_root when its uid is 0 and no rootReason is
# declared for the container, container_shared_id when its uid or gid resolves
# to an account or group other than the declared identity.
emit_container_identity_metrics() {
  local identities="$1"
  local -A declared_uid=() declared_gid=() ctr_to_name=() shared=() roots=() root_reason=()
  local name duid dgid reason cid resolved container kind other cgroup_file cg pid uid gid

  if [[ -z $identities || ! -r $identities ]]; then
    return 0
  fi

  while IFS=$'\t' read -r name duid dgid reason; do
    declared_uid[$name]=$duid
    declared_gid[$name]=$dgid
    root_reason[$name]=$reason
    cid=$(cat "/run/$name/ctr-id" 2>/dev/null || true)
    if [[ $cid =~ ^[0-9a-f]{64}$ ]]; then
      ctr_to_name[$cid]=$name
    fi
  done < <(jq -r 'to_entries[] | [.key, (.value.duid // "-"), (.value.dgid // "-"), (.value.rootReason // "")] | @tsv' "$identities")

  for cgroup_file in /proc/[0-9]*/cgroup; do
    [[ -r $cgroup_file ]] || continue
    cg=$(cat "$cgroup_file" 2>/dev/null || true)
    [[ $cg =~ /libpod-([0-9a-f]{64})\.scope ]] || continue
    name=${ctr_to_name[${BASH_REMATCH[1]}]:-}
    [[ -n $name ]] || continue
    pid=${cgroup_file#/proc/}
    pid=${pid%/cgroup}
    uid=$(awk '/^Uid:/{print $2; exit}' "/proc/$pid/status" 2>/dev/null || true)
    gid=$(awk '/^Gid:/{print $2; exit}' "/proc/$pid/status" 2>/dev/null || true)
    if [[ $uid == 0 ]]; then
      # A recorded reason makes host-root processes compliant
      if [[ -z ${root_reason[$name]:-} ]]; then
        roots[$name]=1
      fi
      continue
    fi
    if [[ $uid != "${declared_uid[$name]}" ]]; then
      resolved=$(account_name "$uid")
      if [[ -n $resolved ]]; then
        shared["$name|uid|$resolved"]=1
      fi
    fi
    if [[ $gid != "${declared_gid[$name]}" ]]; then
      resolved=$(group_name "$gid")
      if [[ -n $resolved ]]; then
        shared["$name|gid|$resolved"]=1
      fi
    fi
  done

  if ((${#shared[@]} > 0)); then
    while IFS='|' read -r container kind other; do
      printf 'node_security_container_shared_id{container="%s",kind="%s",name="%s"} 1\n' \
        "$container" "$kind" "$other"
    done < <(printf '%s\n' "${!shared[@]}" | sort)
  fi
  if ((${#roots[@]} > 0)); then
    while IFS= read -r container; do
      printf 'node_security_container_root{container="%s"} 1\n' "$container"
    done < <(printf '%s\n' "${!roots[@]}" | sort)
  fi
}

NOW=$(date +%s)
REBOOT_REQUIRED=$(check_reboot_required)
GEN_AGE=$(get_generation_age "$NOW")
UID_DUPLICATES=$(count_duplicate_ids /etc/passwd)
GID_DUPLICATES=$(count_duplicate_ids /etc/group)
SEC_JSON=$(systemd-analyze security --json=short 2>/dev/null || echo "[]")

{
  cat <<EOF
# HELP node_security_reboot_required Whether a system reboot is required due to kernel/module mismatch
# TYPE node_security_reboot_required gauge
node_security_reboot_required $REBOOT_REQUIRED
# HELP node_security_generation_age_seconds Seconds since the current NixOS generation was built/switched
# TYPE node_security_generation_age_seconds gauge
node_security_generation_age_seconds $GEN_AGE
# HELP node_systemd_units_by_status_total Number of systemd units by security exposure predicate
# TYPE node_systemd_units_by_status_total gauge
# HELP node_security_duplicate_ids Numeric IDs appearing more than once in /etc/passwd (uid) or /etc/group (gid)
# TYPE node_security_duplicate_ids gauge
node_security_duplicate_ids{kind="uid"} $UID_DUPLICATES
node_security_duplicate_ids{kind="gid"} $GID_DUPLICATES
# HELP node_security_container_shared_id Non-root container process whose uid or gid resolves to an account or group other than the declared identity
# TYPE node_security_container_shared_id gauge
# HELP node_security_container_root Container running host-root processes without a recorded reason
# TYPE node_security_container_root gauge
EOF

  # Socket-activated per-connection instances (nix-daemon@N-...) would mint a new series per connection
  echo "$SEC_JSON" | jq -r '
    map(select(.unit | test("@[0-9]+-") | not)) |
    def count_pred(p): [.[] | select(.predicate == p)] | length;
    "node_systemd_units_by_status_total{status=\"OK\"} \(count_pred("OK"))",
    "node_systemd_units_by_status_total{status=\"MEDIUM\"} \(count_pred("MEDIUM"))",
    "node_systemd_units_by_status_total{status=\"EXPOSED\"} \(count_pred("EXPOSED"))",
    "node_systemd_units_by_status_total{status=\"UNSAFE\"} \(count_pred("UNSAFE"))",
    "# HELP node_systemd_unit_exposure_score Exposure score of systemd unit from systemd-analyze security",
    "# TYPE node_systemd_unit_exposure_score gauge",
    (.[] | select(.unit != null and .exposure != null) | "node_systemd_unit_exposure_score{name=\"" + (.unit | gsub("[\\\\\"\n]"; "")) + "\",status=\"" + (.predicate // "UNKNOWN") + "\"} " + (.exposure | tostring))
  '

  emit_container_identity_metrics "$IDENTITIES"
} >"$TMP_FILE"

chmod 0644 "$TMP_FILE"
mv "$TMP_FILE" "$TEXTFILE_DIR/security_fast.prom"
