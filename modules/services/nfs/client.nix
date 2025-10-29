_:

{
  services.nfs.idmapd.settings.General.Domain = "vpn";

  systemd.tmpfiles.rules = [
    "d /mnt/nfs 0755 root root -"
  ];

  fileSystems."/mnt/nfs/share" = {
    device = "fufuwuqi.vpn:/share";
    fsType = "nfs4";
    options = [
      "nfsvers=4.2"
      "x-systemd.automount"
      "x-systemd.idle-timeout=1min"
      "x-systemd.after=network-online.target"
      "x-systemd.requires=network-online.target"
      "x-systemd.mount-timeout=10s"
      "noauto"
      "nofail"
      "_netdev"
      "timeo=50"
      "retrans=2"
      "rsize=1048576"
      "wsize=1048576"
    ];
  };

  fileSystems."/mnt/nfs/the.files" = {
    device = "fufuwuqi.vpn:/the.files";
    fsType = "nfs4";
    options = [
      "nfsvers=4.2"
      "x-systemd.automount"
      "x-systemd.idle-timeout=1min"
      "x-systemd.after=network-online.target"
      "x-systemd.requires=network-online.target"
      "x-systemd.mount-timeout=10s"
      "noauto"
      "nofail"
      "_netdev"
      "timeo=50"
      "retrans=2"
      "rsize=1048576"
      "wsize=1048576"
    ];
  };
}
