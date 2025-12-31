{ config, lib, ... }:

let
  credentialsFile = "/etc/samba/credentials/fufud";
  mountCommonOptions = [
    "credentials=${credentialsFile}"
    "vers=3.11"
    "uid=${toString config.users.users.fufud.uid}"
    "gid=${toString config.users.users.fufud.uid}"
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
  boot.supportedFilesystems = [ "cifs" ];

  fileSystems."/mnt/smb/share" = {
    device = "//fufuwuqi.vpn/share";
    fsType = "cifs";
    options = mountCommonOptions;
  };

  fileSystems."/mnt/smb/the.files" = {
    device = "//fufuwuqi.vpn/the.files";
    fsType = "cifs";
    options = mountCommonOptions;
  };
}

