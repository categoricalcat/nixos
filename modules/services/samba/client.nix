{
  pkgs,
  ...
}:

let
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

  fileSystems = {
    "/mnt/smb/share" = {
      device = "//smb.fufu.land/share";
      fsType = "cifs";
      options = mountCommonOptions;
    };

    "/mnt/smb/the.files" = {
      device = "//smb.fufu.land/the.files";
      fsType = "cifs";
      options = mountCommonOptions;
    };
  };

  systemd.services.cifs-lazy-umount = {
    description = "Lazy-unmount CIFS shares before network shutdown";
    wantedBy = [ "multi-user.target" ];
    after = [
      "mnt-smb-share.mount"
      "mnt-smb-the.files.mount"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = "-${pkgs.util-linux}/bin/umount -a -l -t cifs";
    };
  };
}
