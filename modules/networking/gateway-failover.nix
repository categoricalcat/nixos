{ addresses, pkgs, ... }:

let
  inherit (addresses.network.lan) interface;
  inherit (addresses.network.lan.ipv4) gateway host;

  metric = 100;
  # Less-famous anycast IP (Level3/CenturyLink). Not in the AdGuardHome
  # upstream list, so pinning it to eno1 (see the tracker route below) does
  # not affect any other service on this host.
  pingTarget = "4.2.2.2";
  pingTimeout = 2;
  pingDeadline = 5;

  checkScript = pkgs.writeShellApplication {
    name = "wan-check";
    runtimeInputs = [ pkgs.iputils ];
    text = ''
      exec ping -I ${interface} -c 1 -W ${toString pingTimeout} -w ${toString pingDeadline} ${pingTarget} >/dev/null 2>&1
    '';
  };

  notifyScript = pkgs.writeShellApplication {
    name = "wan-notify";
    runtimeInputs = [ pkgs.iproute2 ];
    text = ''
      # keepalived passes: TYPE NAME STATE PRIORITY
      state="''${3:-}"
      case "$state" in
        MASTER)
          ip route replace default via ${gateway} dev ${interface} src ${host} metric ${toString metric}
          ;;
        BACKUP|FAULT|STOP)
          ip route del default via ${gateway} dev ${interface} metric ${toString metric} 2>/dev/null || true
          ;;
      esac
    '';
  };
in
{
  # Tracker route for the WAN check. Without it, `ping -I <interface>
  # <pingTarget>` has no on-link or via route through the interface (the
  # metric-100 default is only added by notify_master *after* the check
  # passes), so the kernel ARPs the target on the LAN, the ping fails, and
  # keepalived never leaves FAULT - the box gets stuck on the fallback
  # uplink. Pinning <pingTarget>/32 to <gateway> dev <interface> breaks the
  # chicken-and-egg: the probe always has a path through the primary uplink,
  # so the check reflects real WAN reachability.
  systemd.network.networks."30-eno1".routes = [
    {
      Destination = "${pingTarget}/32";
      Gateway = gateway;
    }
  ];

  services.keepalived = {
    enable = true;
    enableScriptSecurity = true;

    vrrpScripts.check_eno1 = {
      script = "${checkScript}/bin/wan-check";
      interval = 2;
      timeout = pingDeadline;
      rise = 2;
      fall = 2;
      user = "root";
    };

    vrrpInstances.uplink_eno1 = {
      inherit interface;
      state = "BACKUP";
      virtualRouterId = 99;
      priority = 100;
      trackScripts = [ "check_eno1" ];
      # No real VRRP peers; direct adverts to loopback to avoid leaking
      # multicast on the LAN.
      unicastPeers = [ "127.0.0.1" ];
      extraConfig = ''
        nopreempt
        advert_int 1
        notify "${notifyScript}/bin/wan-notify" root
      '';
    };
  };
}
