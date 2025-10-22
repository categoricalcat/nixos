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
      "noauto"
      "nofail"
      "_netdev"
      "timeo=50"
      "retrans=2"
      "rsize=1048576"
      "wsize=1048576"
      "x-systemd.after=wireguard-fufuwuqi.vpn.service"
      "x-systemd.requires=wireguard-fufuwuqi.vpn.service"
      "x-systemd.after=NetworkManager.service"
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
      "timeo=50"
      "retrans=2"
      "rsize=1048576"
      "wsize=1048576"
      "x-systemd.after=wireguard-fufuwuqi.vpn.service"
      "x-systemd.requires=wireguard-fufuwuqi.vpn.service"
      "x-systemd.after=NetworkManager.service"
    ];
  };
}
