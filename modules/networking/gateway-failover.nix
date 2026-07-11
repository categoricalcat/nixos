{
  addresses,
  pkgs,
  ...
}:

let
  cfg = addresses.gatewayFailover;

  isDhcpSide = side: side.gateway == null;
  anyDhcp = sides: builtins.any isDhcpSide sides;

  # Discovers the DHCP gateway for an interface and sets two variables
  # in the caller's shell:
  #   DISCOVERED_GW  - ROUTER from /run/systemd/netif/leases/*
  #   DISCOVERED_SRC - the interface's current IPv4 address
  # We avoid `$(...)` here on purpose: command substitution would put
  # those side effects in a subshell, hiding them from the caller.
  leaseDiscover = ''
    discover_lease() {
      DISCOVERED_GW=
      DISCOVERED_SRC=$(ip -4 addr show dev "$1" 2>/dev/null | awk '/inet /{split($2,a,"/"); print a[1]; exit}')
      [ -z "$DISCOVERED_SRC" ] && return 1
      gv=$(networkctl dhcp-lease "$1" 2>/dev/null | awk -F': *' '/^[ \t]*Router:/ { r=$2 } /^[ \t]*Server Address:/ { s=$2 } END { if (r != "") { split(r, arr, " "); print arr[1] } else if (s != "") { split(s, arr, " "); print arr[1] } }')
      if [ -n "$gv" ]; then
        DISCOVERED_GW=$gv
        return 0
      fi
      return 1
    }
  '';

  # Emit leaseDiscover only when a script actually has a DHCP side, so
  # shellcheck inside writeShellApplication doesn't flag the helper's
  # output variables as unused.
  leaseDiscoverFor = sides: if anyDhcp sides then leaseDiscover else "";

  # Emits shell that sets SIDE_IFACE / SIDE_METRIC / GW / SRC for one side.
  # Static side: GW and SRC come from config.
  # DHCP side:   GW and SRC come from discover_lease.
  resolveSide =
    side:
    let
      gwLine = if side.gateway != null then ''GW="${side.gateway}"'' else ''GW="$DISCOVERED_GW"'';
      srcLine =
        if side.gateway != null then
          (if side.source != null then ''SRC="${side.source}"'' else ''SRC=""'')
        else
          ''SRC="$DISCOVERED_SRC"'';
      discoverLine =
        if side.gateway != null then "" else ''discover_lease "${side.interface}" || return 1'';
    in
    ''
      SIDE_IFACE="${side.interface}"
      SIDE_METRIC="${toString side.metric}"
      ${discoverLine}
      ${gwLine}
      ${srcLine}
    '';

  # Wraps `ip route replace <DEST>` so the optional `src` argument is only
  # added when SRC is non-empty. Avoids array gymnastics under set -u.
  routeReplace = dest: ''
    if [ -n "''${SRC:-}" ]; then
      ip route replace ${dest} via "$GW" dev "$SIDE_IFACE" src "$SRC" metric "$SIDE_METRIC"
    else
      ip route replace ${dest} via "$GW" dev "$SIDE_IFACE" metric "$SIDE_METRIC"
    fi
  '';

  # Pings cfg.pingTarget bound to the primary interface. First installs a
  # /32 to that target via the primary's gateway so the probe always exits
  # via the primary even while in FAULT (default route on fallback).
  checkScript = pkgs.writeShellApplication {
    name = "wan-check";
    runtimeInputs = [
      pkgs.iputils
      pkgs.iproute2
      pkgs.gawk
      pkgs.systemd
    ];
    text = ''
      ${leaseDiscoverFor [ cfg.primary ]}

      resolve_primary() {
        ${resolveSide cfg.primary}
      }

      resolve_primary || exit 1
      ${routeReplace "${cfg.pingTarget}/32"}
      exec ping -I "$SIDE_IFACE" -c 1 -W ${toString cfg.pingTimeout} -w ${toString cfg.pingDeadline} "${cfg.pingTarget}" >/dev/null 2>&1
    '';
  };

  # Switches the default route to the primary on MASTER, to the fallback on
  # FAULT/BACKUP/STOP. Flushes conntrack on every transition so existing
  # NAT sessions rebuild over the now-active WAN.
  notifyScript = pkgs.writeShellApplication {
    name = "wan-notify";
    runtimeInputs = [
      pkgs.iproute2
      pkgs.conntrack-tools
      pkgs.gawk
      pkgs.systemd
    ];
    text = ''
      ${leaseDiscoverFor [
        cfg.primary
        cfg.fallback
      ]}

      resolve_primary() {
        ${resolveSide cfg.primary}
      }
      resolve_fallback() {
        ${resolveSide cfg.fallback}
      }

      state="''${3:-}"
      case "$state" in
        MASTER)
          resolve_primary || exit 1
          ;;
        BACKUP|FAULT|STOP)
          resolve_fallback || exit 1
          ;;
        *)
          exit 0
          ;;
      esac

      ${routeReplace "default"}
      conntrack -F >/dev/null 2>&1 || true
    '';
  };
in
{
  services.keepalived = {
    enable = true;
    enableScriptSecurity = true;

    vrrpScripts."check_${cfg.primary.interface}" = {
      script = "${checkScript}/bin/wan-check";
      interval = 2;
      timeout = cfg.pingDeadline;
      rise = 2;
      fall = 2;
      user = "root";
    };

    vrrpInstances."uplink_${cfg.primary.interface}" = {
      inherit (cfg.primary) interface;
      state = "MASTER";
      inherit (cfg) virtualRouterId priority unicastPeers;
      trackScripts = [ "check_${cfg.primary.interface}" ];
      extraConfig = ''
        advert_int 1
        preempt_delay 0
        notify "${notifyScript}/bin/wan-notify" root
      '';
    };
  };
}
