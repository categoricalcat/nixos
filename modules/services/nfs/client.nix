{
  config,
  lib,
  ...
}:

let
  hasWg = config.networking.wg-quick.interfaces ? "yifuwuqi.vpn";
  hasZerotier = config.services.zerotierone.enable;
in
{
  services.nfs.idmapd.settings.General.Domain = "vpn";

  systemd.tmpfiles.rules = [
    "d /mnt/nfs 0755 root root -"
  ]
  ++ lib.optional hasZerotier "d /mnt/nfs/zero 0755 root root -";

  # WireGuard NFS mounts — only on hosts with wg-quick yifuwuqi.vpn
  fileSystems."/mnt/nfs/share" = lib.mkIf hasWg {
    device = "yifuwuqi.vpn:/share";
    fsType = "nfs4";
    options = [
      "nfsvers=4.2"
      "x-systemd.mount-timeout=10s"
      "noauto"
      "nofail"
      "_netdev"
      "timeo=50"
      "retrans=2"
      "rsize=1048576"
      "wsize=1048576"
      "x-systemd.after=wg-quick-yifuwuqi.vpn.service"
      "x-systemd.requires=wg-quick-yifuwuqi.vpn.service"
    ];
  };

  fileSystems."/mnt/nfs/the.files" = lib.mkIf hasWg {
    device = "yifuwuqi.vpn:/the.files";
    fsType = "nfs4";
    options = [
      "nfsvers=4.2"
      "x-systemd.mount-timeout=10s"
      "noauto"
      "nofail"
      "_netdev"
      "timeo=50"
      "retrans=2"
      "rsize=1048576"
      "wsize=1048576"
      "x-systemd.after=wg-quick-yifuwuqi.vpn.service"
      "x-systemd.requires=wg-quick-yifuwuqi.vpn.service"
    ];
  };

  # ZeroTier NFS mounts — only on hosts with ZeroTier enabled
  fileSystems."/mnt/nfs/zero/share" = lib.mkIf hasZerotier {
    device = "10.0.0.1:/share";
    fsType = "nfs4";
    options = [
      "nfsvers=4.2"
      "x-systemd.mount-timeout=10s"
      "noauto"
      "nofail"
      "_netdev"
      "timeo=50"
      "retrans=2"
      "rsize=1048576"
      "wsize=1048576"
      "x-systemd.after=zerotierone.service"
      "x-systemd.requires=zerotierone.service"
    ];
  };

  fileSystems."/mnt/nfs/zero/the.files" = lib.mkIf hasZerotier {
    device = "10.0.0.1:/the.files";
    fsType = "nfs4";
    options = [
      "nfsvers=4.2"
      "x-systemd.mount-timeout=10s"
      "noauto"
      "nofail"
      "_netdev"
      "timeo=50"
      "retrans=2"
      "rsize=1048576"
      "wsize=1048576"
      "x-systemd.after=zerotierone.service"
      "x-systemd.requires=zerotierone.service"
    ];
  };
}
