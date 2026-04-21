{ addresses, pkgs, ... }:

let
  inherit (addresses.network.lan) interface;
  inherit (addresses.network.lan.ipv4) gateway host;

  metric = 100;
  pingTarget = "8.8.8.8";
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
      interface = interface;
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
