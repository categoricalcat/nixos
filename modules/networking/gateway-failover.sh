#!/usr/bin/env bash
# Gateway Failover Monitor
# Keeps the preferred uplink route installed only while it passes health checks.

: "${INTERFACE:?Missing INTERFACE}"
: "${GATEWAY:?Missing GATEWAY}"
: "${CHECK_IPS:?Missing CHECK_IPS}"
: "${PING_COUNT:?Missing PING_COUNT}"
: "${PING_TIMEOUT:?Missing PING_TIMEOUT}"
: "${DEADLINE:?Missing DEADLINE}"
: "${METRIC:?Missing METRIC}"
: "${INTERVAL:?Missing INTERVAL}"
: "${FAILURE_THRESHOLD:?Missing FAILURE_THRESHOLD}"
: "${RECOVERY_THRESHOLD:?Missing RECOVERY_THRESHOLD}"
: "${OPERSTATE_FILE:=/sys/class/net/$INTERFACE/operstate}"

current_state="unknown"
consecutive_failures=0
consecutive_successes=0

read -r -a check_ips <<< "$CHECK_IPS"
num_ips=${#check_ips[@]}
current_ip_index=0

log() {
  local level="$1"
  shift

  if [[ "$level" == "WARN" || "$level" == "ERROR" ]]; then
    printf '[%s] %s\n' "$level" "$*" >&2
    return
  fi

  printf '[%s] %s\n' "$level" "$*"
}

default_route_present() {
  local routes

  routes=$(ip -4 route show default dev "$INTERFACE" 2>/dev/null || true)
  [[ -n "$routes" ]] &&
    [[ "$routes" == *"via $GATEWAY"* ]] &&
    [[ "$routes" == *"metric $METRIC"* ]]
}

log_default_routes() {
  local routes

  routes=$(ip -4 route show default 2>/dev/null || true)
  if [[ -z "$routes" ]]; then
    log WARN "No IPv4 default routes are currently installed"
    return
  fi

  while IFS= read -r line; do
    log INFO "Default route: $line"
  done <<< "$routes"
}

remove_probe_routes() {
  local ip

  for ip in "${check_ips[@]}"; do
    ip route del "$ip" via "$GATEWAY" dev "$INTERFACE" 2>/dev/null || true
  done
}

remove_default_route() {
  ip route del default via "$GATEWAY" dev "$INTERFACE" metric "$METRIC" onlink 2>/dev/null && return 0
  ip route del default via "$GATEWAY" dev "$INTERFACE" metric "$METRIC" 2>/dev/null && return 0
  ip route del default via "$GATEWAY" dev "$INTERFACE" 2>/dev/null && return 0
  ip route del default dev "$INTERFACE" metric "$METRIC" 2>/dev/null && return 0
  return 1
}

cleanup() {
  trap - EXIT
  log INFO "Shutting down, removing managed routes for $INTERFACE"

  remove_probe_routes
  remove_default_route || true
}

trap cleanup EXIT

ensure_route_absent() {
  local reason="$1"
  local route_was_present=0

  if default_route_present; then
    route_was_present=1
    remove_default_route || true
  fi

  remove_probe_routes

  if default_route_present; then
    log ERROR "$reason, but the default route via $INTERFACE is still present"
    log_default_routes
    return 1
  fi

  if (( route_was_present )); then
    log WARN "$reason, removed default route via $INTERFACE"
    log_default_routes
  elif [[ "$current_state" != "down" && "$current_state" != "link-down" ]]; then
    log INFO "$reason, primary default route via $INTERFACE was already absent"
    log_default_routes
  fi

  return 0
}

ensure_route_present() {
  if ! ip route replace default via "$GATEWAY" dev "$INTERFACE" metric "$METRIC" onlink 2>/dev/null; then
    log ERROR "Failed to install default route via $INTERFACE"
    log_default_routes
    return 1
  fi

  if ! default_route_present; then
    log ERROR "Tried to install default route via $INTERFACE, but it is still missing"
    log_default_routes
    return 1
  fi

  if [[ "$current_state" != "up" ]]; then
    log INFO "Gateway reachable via $INTERFACE, restored default route (metric $METRIC)"
    log_default_routes
  fi

  return 0
}

if (( num_ips == 0 )); then
  log ERROR "No health-check IPs configured"
  exit 1
fi

if ! [[ "$FAILURE_THRESHOLD" =~ ^[1-9][0-9]*$ && "$RECOVERY_THRESHOLD" =~ ^[1-9][0-9]*$ ]]; then
  log ERROR "FAILURE_THRESHOLD and RECOVERY_THRESHOLD must be positive integers"
  exit 1
fi

log INFO "Gateway failover monitor initializing. Interface: $INTERFACE, Gateway: $GATEWAY"
log INFO "Configured check IPs: ${check_ips[*]}"
log INFO "Using failure threshold $FAILURE_THRESHOLD and recovery threshold $RECOVERY_THRESHOLD"

while true; do
  if ! read -r operstate < "$OPERSTATE_FILE"; then
    operstate="down"
  fi

  if [[ "$operstate" != "up" ]]; then
    consecutive_failures=0
    consecutive_successes=0
    if ensure_route_absent "Interface $INTERFACE is $operstate"; then
      if [[ "$current_state" != "link-down" ]]; then
        log WARN "Interface $INTERFACE is $operstate, skipping health checks"
      fi
      current_state="link-down"
    fi
    sleep "$INTERVAL"
    continue
  fi

  check_ip="${check_ips[$current_ip_index]}"
  current_ip_index=$(( (current_ip_index + 1) % num_ips ))

  if ! ip route replace "$check_ip" via "$GATEWAY" dev "$INTERFACE" onlink 2>/dev/null; then
    log ERROR "Failed to set host route for $check_ip via $INTERFACE"
    sleep "$INTERVAL"
    continue
  fi

  if ping -I "$INTERFACE" -c "$PING_COUNT" -W "$PING_TIMEOUT" -w "$DEADLINE" "$check_ip" > /dev/null 2>&1; then
    consecutive_failures=0
    if (( consecutive_successes < RECOVERY_THRESHOLD )); then
      consecutive_successes=$((consecutive_successes + 1))
    fi

    if [[ "$current_state" != "up" && "$consecutive_successes" -eq 1 ]]; then
      log INFO "Primary path reachable again via $check_ip (${consecutive_successes}/${RECOVERY_THRESHOLD})"
    fi

    if [[ "$current_state" != "up" && "$consecutive_successes" -ge "$RECOVERY_THRESHOLD" ]]; then
      if ensure_route_present; then
        current_state="up"
      fi
    fi
  else
    consecutive_successes=0
    if (( consecutive_failures < FAILURE_THRESHOLD )); then
      consecutive_failures=$((consecutive_failures + 1))
    fi

    if [[ "$current_state" == "up" && "$consecutive_failures" -lt "$FAILURE_THRESHOLD" ]]; then
      log WARN "Primary health check failed for $check_ip (${consecutive_failures}/${FAILURE_THRESHOLD})"
    fi

    if [[ "$consecutive_failures" -ge "$FAILURE_THRESHOLD" ]]; then
      if ensure_route_absent "Primary health checks failed via $INTERFACE (last target: $check_ip)" ; then
        current_state="down"
      fi
    fi
  fi

  sleep "$INTERVAL"
done