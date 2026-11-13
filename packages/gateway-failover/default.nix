{
  addresses,
  allAddresses,
  pkgs,
  lib,
  ...
}:

let
  inherit (addresses.gatewayFailover) primary pingTargets;
  inherit (allAddresses.monitoring) nodeTextfileDir;

  # Owns the primary default route: present only while the primary uplink is
  # debounced-healthy and re-asserted every tick, so it converges from any
  # route-table state instead of depending on a transition being observed.
  # The fallback default sits at a higher metric and belongs to networkd
  # (UseGateway on the fallback link), which restores it with every lease.
  monitor = pkgs.writeShellApplication {
    name = "wan-monitor";
    runtimeInputs = [
      pkgs.conntrack-tools
      pkgs.coreutils
      pkgs.gawk
      pkgs.iproute2
      pkgs.iputils
      pkgs.systemd
    ];
    text = ''
      IFACE=${lib.escapeShellArg primary.interface}
      METRIC=${toString primary.metric}
      TARGETS=(${lib.escapeShellArgs pingTargets})
      PROM=${lib.escapeShellArg "${nodeTextfileDir}/gateway_failover.prom"}
      # Straight ticks with a reply that restore the route, and straight ticks
      # without one that withdraw it.
      RISE=2
      FALL=4

      # 0: a target answered. 1: none did. 2: no address or gateway to probe through.
      probe() {
        SRC=$(ip -4 -o addr show dev "$IFACE" scope global 2>/dev/null | awk '{ split($4, a, "/"); print a[1]; exit }')
        GW=${
          if primary.gateway != null then
            lib.escapeShellArg primary.gateway
          else
            # Router option of the current lease.
            ''$(networkctl dhcp-lease "$IFACE" 3 2>/dev/null | awk '$1 == 3 { print $3; exit }')''
        }
        if [ -z "$SRC" ] || [ -z "$GW" ]; then
          return 2
        fi
        # Pin the targets to the primary, or the probes would follow the
        # default route out of the fallback while the primary is withdrawn.
        for target in "''${TARGETS[@]}"; do
          ip route replace "$target/32" via "$GW" dev "$IFACE" src "$SRC" metric "$METRIC" 2>/dev/null || return 2
        done
        for target in "''${TARGETS[@]}"; do
          if ping -I "$IFACE" -c 1 -W 1 "$target" >/dev/null 2>&1; then
            return 0
          fi
        done
        return 1
      }

      publish() {
        cat >"$PROM.tmp" <<EOF && mv "$PROM.tmp" "$PROM"
      # HELP gateway_failover_primary_active Whether the primary uplink is active.
      # TYPE gateway_failover_primary_active gauge
      gateway_failover_primary_active{interface="$IFACE"} $up
      # HELP gateway_failover_last_transition_timestamp_seconds Unix time of the active gateway transition.
      # TYPE gateway_failover_last_transition_timestamp_seconds gauge
      gateway_failover_last_transition_timestamp_seconds $(date +%s)
      EOF
      }

      # Adopt the kernel's state, so a restart neither moves traffic nor
      # flushes conntrack.
      up=0
      if [ -n "$(ip -4 route show default dev "$IFACE" metric "$METRIC" 2>/dev/null)" ]; then
        up=1
      fi
      # What the exporter last saw. It goes stale whenever the route changed
      # while this was not running, a reboot included.
      published=$(awk '/^gateway_failover_primary_active/ { print $NF }' "$PROM" 2>/dev/null || true)
      ok=0
      bad=0

      while :; do
        # One tick. Probing time counts towards it.
        sleep 2 &
        tick=$!

        status=0
        probe || status=$?
        case $status in
          0) ok=$((ok + 1)) bad=0 ;;
          1) ok=0 bad=$((bad + 1)) ;;
          *) ok=0 bad=$FALL ;;
        esac
        if [ "$ok" -ge "$RISE" ]; then
          up=1
        elif [ "$bad" -ge "$FALL" ]; then
          up=0
        fi

        if [ "$up" = 1 ]; then
          ip route replace default via "$GW" dev "$IFACE" src "$SRC" metric "$METRIC"
        else
          ip route del default dev "$IFACE" metric "$METRIC" 2>/dev/null || true
        fi

        if [ "$up" != "$published" ]; then
          # Tracked flows still carry the other uplink's source address.
          conntrack -F >/dev/null 2>&1 || true
          publish || echo "cannot write $PROM" >&2
          published=$up
          case $up$status in
            1?) echo "$IFACE active: default via $GW metric $METRIC" ;;
            00) echo "$IFACE inactive: awaiting $RISE clean probes" ;;
            01) echo "$IFACE inactive: no reply from ''${TARGETS[*]}" ;;
            *) echo "$IFACE inactive: no address or gateway" ;;
          esac
        fi

        wait "$tick"
      done
    '';
  };
in
{
  systemd = {
    tmpfiles.rules = [
      "d ${nodeTextfileDir} 0755 root root - -"
    ];

    # wan-monitor's routes are declared in no .network file, so networkd would
    # sweep them whenever it reconfigures the link. The switch lives in
    # networkd.conf(5) [Network] (global), not in per-link .network files.
    network.config.networkConfig.ManageForeignRoutes = false;

    services.wan-monitor = {
      description = "Primary uplink monitor and default route owner";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      # A crash loop must not end with the default route unattended.
      startLimitIntervalSec = 0;
      serviceConfig = {
        ExecStart = lib.getExe monitor;
        Restart = "always";
        RestartSec = 2;
      };
    };
  };
}
