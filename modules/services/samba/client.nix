{
  config,
  lib,
  ...
}:

let
  addresses = import ../../addresses.nix;

  hasTailscale = config.services.tailscale.enable;
  hasZerotier = config.services.zerotierone.enable;

  credentialsFile = "/etc/samba/credentials/yi";
  mountCommonOptions = [
    "credentials=${credentialsFile}"
    "vers=3.11"
    "uid=yi"
    "gid=yi"
    "file_mode=0664"
    "dir_mode=0775"
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

  # ZeroTier Samba mounts — only on hosts with ZeroTier enabled
  fileSystems."/mnt/smb/zero/share" = lib.mkIf hasZerotier {
    device = "//${addresses.hosts.yifuwuqi.network.zerotier.ipv4.host}/share";
    fsType = "cifs";
    options = mountCommonOptions ++ [
      "x-systemd.after=zerotierone.service"
      "x-systemd.requires=zerotierone.service"
    ];
  };

  fileSystems."/mnt/smb/zero/the.files" = lib.mkIf hasZerotier {
    device = "//${addresses.hosts.yifuwuqi.network.zerotier.ipv4.host}/the.files";
    fsType = "cifs";
    options = mountCommonOptions ++ [
      "x-systemd.after=zerotierone.service"
      "x-systemd.requires=zerotierone.service"
    ];
  };
}
