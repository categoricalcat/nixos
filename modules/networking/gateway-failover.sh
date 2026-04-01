#!/usr/bin/env bash
# Gateway Failover Monitor
# Enforces declarative routing states and includes lifecycle management.

: "${INTERFACE:?Missing INTERFACE}"
: "${GATEWAY:?Missing GATEWAY}"
: "${CHECK_IPS:?Missing CHECK_IPS}"
: "${PING_COUNT:?Missing PING_COUNT}"
: "${PING_TIMEOUT:?Missing PING_TIMEOUT}"
: "${DEADLINE:?Missing DEADLINE}"
: "${METRIC:?Missing METRIC}"
: "${INTERVAL:?Missing INTERVAL}"

# State tracker to prevent log spam and redundant operations
current_state="unknown"

# Convert space-separated string to array
read -r -a check_ips <<< "$CHECK_IPS"
num_ips=${#check_ips[@]}
current_ip_index=0

logger -t gateway-failover "[STARTUP] Gateway failover monitor initializing. Interface: $INTERFACE, Gateway: $GATEWAY"
logger -t gateway-failover "[STARTUP] Configured check IPs: ${check_ips[*]}"

# Declarative cleanup on daemon termination
cleanup() {
  trap - EXIT
  logger -t gateway-failover "Shutting down, removing managed routes for $INTERFACE"
  for ip in "${check_ips[@]}"; do
    ip route del "$ip" via "$GATEWAY" dev "$INTERFACE" 2>/dev/null || true
  done
  ip route del default via "$GATEWAY" dev "$INTERFACE" metric "$METRIC" 2>/dev/null || true
}

trap cleanup EXIT

# Enforces the absent state of the default route
ensure_route_absent() {
  if [[ "$current_state" != "down" && "$current_state" != "link-down" ]]; then
    # Idempotent deletion ignores errors if the route is already gone
    ip route del default via "$GATEWAY" dev "$INTERFACE" metric "$METRIC" 2>/dev/null || true
    logger -t gateway-failover "Gateway/Link unreachable via $INTERFACE, removed default route"
  fi
  return 0
}

# Enforces the present state of the default route
ensure_route_present() {
  if [[ "$current_state" != "up" ]]; then
    # 'replace' is declarative: it creates or updates the route without duplicating it,
    # avoiding the need to iteratively parse 'ip route show'.
    if ip route replace default via "$GATEWAY" dev "$INTERFACE" metric "$METRIC" onlink 2>/dev/null; then
      logger -t gateway-failover "Gateway reachable via $INTERFACE, restored default route (metric $METRIC)"
    else
      logger -t gateway-failover "Failed to add default route via $INTERFACE"
      return 1
    fi
  fi
  return 0
}

# main
while true; do
  operstate=$(cat "/sys/class/net/$INTERFACE/operstate" 2>/dev/null || echo "down")

  if [[ "$operstate" != "up" ]]; then
    ensure_route_absent
    if [[ "$current_state" != "link-down" ]]; then
      logger -t gateway-failover "Interface $INTERFACE is $operstate, skipping health checks"
      current_state="link-down"
    fi
    sleep "$INTERVAL"
    continue
  fi

  # Get the next check IP and advance the index
  CHECK_IP="${check_ips[$current_ip_index]}"
  current_ip_index=$(( (current_ip_index + 1) % num_ips ))

  # Declaratively ensure the host route exists for the L3 health check
  if ! ip route replace "$CHECK_IP" via "$GATEWAY" dev "$INTERFACE" onlink 2>/dev/null; then
    logger -t gateway-failover "Failed to set host route for $CHECK_IP via $INTERFACE"
    sleep "$INTERVAL"
    continue
  fi

  # Execute health check
  logger -t gateway-failover "[CHECK] Pinging $CHECK_IP via $INTERFACE..."
  if ping -I "$INTERFACE" -c "$PING_COUNT" -W "$PING_TIMEOUT" -w "$DEADLINE" "$CHECK_IP" > /dev/null 2>&1; then
    if [[ "$current_state" != "up" ]]; then
      logger -t gateway-failover "[UP] Ping to $CHECK_IP successful."
    fi
    if ensure_route_present; then
      current_state="up"
    fi
  else
    logger -t gateway-failover "[DOWN] Ping to $CHECK_IP failed!"
    ensure_route_absent
    current_state="down"
  fi

  sleep "$INTERVAL"
done