_:

{
  services.nfs.idmapd.settings.General.Domain = "vpn";

  systemd.tmpfiles.rules = [
    "d /mnt/nfs 0755 root root -"
    "d /mnt/nfs/share 0755 root root -"
    "d /mnt/nfs/the.files 0755 root root -"
  ];

  fileSystems."/mnt/nfs/share" = {
    device = "fufuwuqi.vpn:/share";
    fsType = "nfs4";
    options = [
      "nfsvers=4.2"
      "x-systemd.automount"
      "noauto"
      "nofail"
      "_netdev"
      "timeo=600"
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
      "noauto"
      "nofail"
      "_netdev"
      "timeo=600"
      "retrans=2"
      "rsize=1048576"
      "wsize=1048576"
    ];
  };
}
