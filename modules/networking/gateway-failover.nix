{
  addresses,
  lib,
  pkgs,
  ...
}:

let
  cfg = addresses.gatewayFailover;
  isDhcp = cfg.gateway == null;
  hasDhcpPingTarget = isDhcp && cfg.pingTarget != null;
  pingTargetHost =
    if cfg.pingTarget == null then
      null
    else
      lib.removeSuffix "]" (lib.removePrefix "[" (lib.removeSuffix ":53" cfg.pingTarget));

  leaseDiscover = ''
    discover_lease() {
      LEASE_ADDR=$(ip -4 addr show dev "$1" 2>/dev/null | awk '/inet /{split($2,a,"/"); print a[1]; exit}')
      [ -z "$LEASE_ADDR" ] && return 1
      for f in /run/systemd/netif/leases/*; do
        [ -f "$f" ] || continue
        gv=$(awk -F= -v ip="$LEASE_ADDR" '$1=="ADDRESS"&&$2==ip{f=1; next} f&&$1=="ROUTER"{print $2; exit}' "$f")
        [ -n "$gv" ] && { echo "$gv"; return 0; }
      done
      return 1
    }
  '';

  checkScript = pkgs.writeShellApplication {
    name = "wan-check";
    runtimeInputs = [
      pkgs.iputils
    ]
    ++ lib.optionals isDhcp [ pkgs.gawk ]
    ++ lib.optionals hasDhcpPingTarget [ pkgs.iproute2 ];
    text =
      if isDhcp then
        if cfg.pingTarget == null then
          ''
            ${leaseDiscover}
            GW=$(discover_lease ${cfg.interface})
            [ -z "$GW" ] && exit 1
            exec ping -I ${cfg.interface} -c 1 -W ${toString cfg.pingTimeout} -w ${toString cfg.pingDeadline} "$GW" >/dev/null 2>&1
          ''
        else
          ''
            ${leaseDiscover}
            GW=$(discover_lease ${cfg.interface})
            SRC=$LEASE_ADDR
            [ -z "$GW" ] && exit 1
            TARGET=${lib.escapeShellArg pingTargetHost}
            ip route replace "$TARGET/32" via "$GW" dev ${cfg.interface} src "$SRC" metric ${toString cfg.metric}
            exec ping -I ${cfg.interface} -c 1 -W ${toString cfg.pingTimeout} -w ${toString cfg.pingDeadline} "$TARGET" >/dev/null 2>&1
          ''
      else
        ''
          exec ping -I ${cfg.interface} -c 1 -W ${toString cfg.pingTimeout} -w ${toString cfg.pingDeadline} ${pingTargetHost} >/dev/null 2>&1
        '';
  };

  notifyScript = pkgs.writeShellApplication {
    name = "wan-notify";
    runtimeInputs = [ pkgs.iproute2 ] ++ lib.optionals isDhcp [ pkgs.gawk ];
    text =
      if isDhcp then
        ''
          ${leaseDiscover}
          GW=$(discover_lease ${cfg.interface})
          SRC=$LEASE_ADDR
          [ -z "$GW" ] && exit 1
          state="''${3:-}"
          case "$state" in
            MASTER)
              ip route replace default via "$GW" dev ${cfg.interface} src "$SRC" metric ${toString cfg.metric}
              ;;
            BACKUP|FAULT|STOP)
              ip route del default via "$GW" dev ${cfg.interface} metric ${toString cfg.metric} 2>/dev/null || true
              ;;
          esac
        ''
      else
        ''
          state="''${3:-}"
          case "$state" in
            MASTER)
              ip route replace default via ${cfg.gateway} dev ${cfg.interface} src ${cfg.source} metric ${toString cfg.metric}
              ;;
            BACKUP|FAULT|STOP)
              ip route del default via ${cfg.gateway} dev ${cfg.interface} metric ${toString cfg.metric} 2>/dev/null || true
              ;;
          esac
        '';
  };
in
{
  # Tracker route for static mode only: pins the ping target through the
  # managed interface so the check can always reach it even before keepalived
  # installs the default route.
  systemd.network.networks = lib.mkIf (!isDhcp) {
    "30-${cfg.interface}" = {
      matchConfig.Name = cfg.interface;
      routes = [
        {
          Destination = "${pingTargetHost}/32";
          Gateway = cfg.gateway;
        }
      ];
    };
  };

  services.keepalived = {
    enable = true;
    enableScriptSecurity = true;

    vrrpScripts."check_${cfg.interface}" = {
      script = "${checkScript}/bin/wan-check";
      interval = 2;
      timeout = cfg.pingDeadline;
      rise = 2;
      fall = 2;
      user = "root";
    };

    vrrpInstances."uplink_${cfg.interface}" = {
      inherit (cfg) interface;
      state = "BACKUP";
      inherit (cfg) virtualRouterId priority unicastPeers;
      trackScripts = [ "check_${cfg.interface}" ];
      extraConfig = ''
        nopreempt
        advert_int 1
        notify "${notifyScript}/bin/wan-notify" root
      '';
    };
  };
}
