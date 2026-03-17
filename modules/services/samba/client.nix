{ config, ... }:

let
  credentialsFile = "/etc/samba/credentials/yi";
  mountCommonOptions = [
    "credentials=${credentialsFile}"
    "vers=3.11"
    "uid=${toString config.users.users.yi.uid}"
    "gid=${toString config.users.users.yi.uid}"
    "file_mode=0664"
    "dir_mode=0775"
    "x-systemd.automount"
    "x-systemd.idle-timeout=1min"
    "x-systemd.mount-timeout=10s"
    "noauto"
    "nofail"
    "_netdev"
    "soft"
    "timeo=50"
    "retrans=2"
  ];
in
{
  sops.secrets."samba/credentials/yi" = {
    mode = "0600";
    path = credentialsFile;
  };

  boot.supportedFilesystems = [ "cifs" ];

  fileSystems."/mnt/smb/share" = {
    device = "//yifuwuqi.vpn/share";
    fsType = "cifs";
    options = mountCommonOptions;
  };

  fileSystems."/mnt/smb/the.files" = {
    device = "//yifuwuqi.vpn/the.files";
    fsType = "cifs";
    options = mountCommonOptions;
  };

  fileSystems."/mnt/smb/zero/share" = {
    device = "//yifuwuqi.zero/share";
    fsType = "cifs";
    options = mountCommonOptions;
  };

  fileSystems."/mnt/smb/zero/the.files" = {
    device = "//yifuwuqi.zero/the.files";
    fsType = "cifs";
    options = mountCommonOptions;
  };
}
