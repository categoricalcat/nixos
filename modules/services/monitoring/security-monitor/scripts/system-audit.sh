#!/usr/bin/env bash
set -euo pipefail

# Textfile collector directory for node_exporter
TEXTFILE_DIR="${1:-/var/lib/prometheus-node-exporter/textfile}"
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

NOW=$(date +%s)
REBOOT_REQUIRED=$(check_reboot_required)
GEN_AGE=$(get_generation_age "$NOW")
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
EOF

  echo "$SEC_JSON" | jq -r '
    def count_pred(p): [.[] | select(.predicate == p)] | length;
    "node_systemd_units_by_status_total{status=\"OK\"} \(count_pred("OK"))",
    "node_systemd_units_by_status_total{status=\"MEDIUM\"} \(count_pred("MEDIUM"))",
    "node_systemd_units_by_status_total{status=\"EXPOSED\"} \(count_pred("EXPOSED"))",
    "node_systemd_units_by_status_total{status=\"UNSAFE\"} \(count_pred("UNSAFE"))",
    "# HELP node_systemd_unit_exposure_score Exposure score of systemd unit from systemd-analyze security",
    "# TYPE node_systemd_unit_exposure_score gauge",
    (.[] | select(.unit != null and .exposure != null) | "node_systemd_unit_exposure_score{name=\"" + (.unit | gsub("[\\\\\"\n]"; "")) + "\",status=\"" + (.predicate // "UNKNOWN") + "\"} " + (.exposure | tostring))
  '
} >"$TMP_FILE"

chmod 0644 "$TMP_FILE"
mv "$TMP_FILE" "$TEXTFILE_DIR/security_fast.prom"
