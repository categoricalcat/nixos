{
  config,
  lib,
  ...
}:

let
  hasWg = config.networking.wg-quick.interfaces ? "yifuwuqi.vpn";
  hasZerotier = config.services.zerotierone.enable;

  credentialsFile = "/etc/samba/credentials/yi";
  mountCommonOptions = [
    "credentials=${credentialsFile}"
    "vers=3.11"
    "uid=yi"
    "gid=yi"
    "file_mode=0664"
    "dir_mode=0775"
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

  # WireGuard Samba mounts — only on hosts with wg-quick yifuwuqi.vpn
  fileSystems."/mnt/smb/share" = lib.mkIf hasWg {
    device = "//yifuwuqi.vpn/share";
    fsType = "cifs";
    options = mountCommonOptions ++ [
      "x-systemd.after=wg-quick-yifuwuqi.vpn.service"
      "x-systemd.requires=wg-quick-yifuwuqi.vpn.service"
    ];
  };

  fileSystems."/mnt/smb/the.files" = lib.mkIf hasWg {
    device = "//yifuwuqi.vpn/the.files";
    fsType = "cifs";
    options = mountCommonOptions ++ [
      "x-systemd.after=wg-quick-yifuwuqi.vpn.service"
      "x-systemd.requires=wg-quick-yifuwuqi.vpn.service"
    ];
  };

  # ZeroTier Samba mounts — only on hosts with ZeroTier enabled
  fileSystems."/mnt/smb/zero/share" = lib.mkIf hasZerotier {
    device = "//yifuwuqi.zero/share";
    fsType = "cifs";
    options = mountCommonOptions ++ [
      "x-systemd.after=zerotierone.service"
      "x-systemd.requires=zerotierone.service"
    ];
  };

  fileSystems."/mnt/smb/zero/the.files" = lib.mkIf hasZerotier {
    device = "//yifuwuqi.zero/the.files";
    fsType = "cifs";
    options = mountCommonOptions ++ [
      "x-systemd.after=zerotierone.service"
      "x-systemd.requires=zerotierone.service"
    ];
  };
}
