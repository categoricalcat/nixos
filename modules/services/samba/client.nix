{
  config,
  lib,
  pkgs,
  ...
}:

let
  addresses = import ../../addresses.nix;

  hasTailscale = config.services.tailscale.enable;
  hasNetbird = config.services.netbird.enable;

  credentialsFile = "/etc/samba/credentials/yi";
  mountCommonOptions = [
    "credentials=${credentialsFile}"
    "vers=3.11"
    "uid=yi"
    "gid=yi"
    "file_mode=0664"
    "dir_mode=0775"
    "mfsymlinks"
    "x-systemd.after=sops-install-secrets.service"
    "x-systemd.requires=sops-install-secrets.service"
    "x-systemd.automount"
    "x-systemd.idle-timeout=1min"
    "x-systemd.mount-timeout=10s"
    "noauto"
    "nofail"
    "_netdev"
  ];
in
{
  sops.secrets."samba/credentials/yi" = {
    mode = "0600";
    path = credentialsFile;
  };

  boot.supportedFilesystems = [ "cifs" ];

  # Tailscale Samba mounts — only on hosts with Tailscale enabled
  fileSystems."/mnt/smb/share" = lib.mkIf hasTailscale {
    device = "//${addresses.hosts.yifuwuqi.network.tailscale.ipv4.host}/share";
    fsType = "cifs";
    options = mountCommonOptions ++ [
      "x-systemd.after=tailscaled.service"
      "x-systemd.requires=tailscaled.service"
    ];
  };

  fileSystems."/mnt/smb/the.files" = lib.mkIf hasTailscale {
    device = "//${addresses.hosts.yifuwuqi.network.tailscale.ipv4.host}/the.files";
    fsType = "cifs";
    options = mountCommonOptions ++ [
      "x-systemd.after=tailscaled.service"
      "x-systemd.requires=tailscaled.service"
    ];
  };

  # Netbird Samba mounts — only on hosts with Netbird enabled
  fileSystems."/mnt/smb/nb/share" = lib.mkIf hasNetbird {
    device = "//${addresses.hosts.yifuwuqi.network.netbird.ipv4.host}/share";
    fsType = "cifs";
    options = mountCommonOptions ++ [
      "x-systemd.after=netbird.service"
      "x-systemd.requires=netbird.service"
    ];
  };

  fileSystems."/mnt/smb/nb/the.files" = lib.mkIf hasNetbird {
    device = "//${addresses.hosts.yifuwuqi.network.netbird.ipv4.host}/the.files";
    fsType = "cifs";
    options = mountCommonOptions ++ [
      "x-systemd.after=netbird.service"
      "x-systemd.requires=netbird.service"
    ];
  };

  systemd.services.cifs-lazy-umount = lib.mkIf (hasTailscale || hasNetbird) {
    description = "Lazy-unmount CIFS shares before VPN/network shutdown";
    wantedBy = [ "multi-user.target" ];
    after =
      lib.optionals hasTailscale [
        "tailscaled.service"
        "mnt-smb-share.mount"
        "mnt-smb-the.files.mount"
      ]
      ++ lib.optionals hasNetbird [
        "netbird.service"
        "mnt-smb-nb-share.mount"
        "mnt-smb-nb-the.files.mount"
      ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = "-${pkgs.util-linux}/bin/umount -a -l -t cifs";
    };
  };
}
