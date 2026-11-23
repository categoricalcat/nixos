{
  pkgs,
  lib,
  addresses,
  ...
}:

let
  cockpit = addresses.services.cockpit;
  port = toString cockpit.port;
in
{
  services.cockpit = {
    enable = true;
    inherit (cockpit) port;
    plugins = with pkgs; [
      cockpit-podman
      cockpit-files
      cockpit-dockermanager
      cockpit-machines
      cockpit-zfs
    ];
    allowed-origins = [
      "http://localhost:${port}"
      "http://${addresses.hostName}.local:${port}"
      "https://${addresses.hostName}.local:${port}"
      "https://${cockpit.domain}"
    ];
    settings = {
      WebService = {
        AllowUnencrypted = true;
        ProtocolHeader = "X-Forwarded-Proto";
        ForwardedForHeader = "X-Forwarded-For";
      };
    };
  };

  # NixOS ships kexec for fast reboot (boot.kexec), which makes Cockpit
  # show its Fedora kdump page and the "install kexec-tools" alert.
  # That page wants kdump.service, which NixOS does not provide.
  # Placed under /etc/xdg/cockpit because /etc/pam/environment sets
  # XDG_CONFIG_DIRS=/etc/xdg:... (without /etc) for cockpit-bridge sessions.
  environment.etc."xdg/cockpit/kdump.override.json".text = builtins.toJSON {
    conditions = [
      { "path-exists" = "/var/empty/cockpit-kdump-enabled"; }
    ];
  };

  environment.systemPackages = with pkgs; [
    sysstat
  ];

  # cockpit-ws only; PAM session processes move into logind scopes and escape
  # these settings. Not the full systemdHardening set: logins need the setuid
  # cockpit-session helper (NoNewPrivileges/RestrictSUIDSGID stay off), and
  # the bridge manages the system by design.
  systemd.services.cockpit = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      ProtectSystem = "full";
      PrivateTmp = true;
      ProtectClock = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      RestrictRealtime = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
    };
  };

  # Loopback-only behind the local ingress. The leading empty entry matches
  # the nixpkgs module's socket workaround.
  systemd.sockets.cockpit.listenStreams = lib.mkForce [
    ""
    "127.0.0.1:${port}"
  ];
}
