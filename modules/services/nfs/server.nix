{ lib, ... }:

{
  services.nfs.idmapd.settings.General.Domain = "vpn";

  services.nfs.server = {
    enable = true;
    exports = ''
      /srv/nfs 10.100.0.0/24(rw,fsid=0,no_subtree_check,crossmnt,sec=sys) 192.168.1.0/24(rw,fsid=0,no_subtree_check,crossmnt,sec=sys)
      /srv/nfs/share 10.100.0.0/24(rw,no_subtree_check,sec=sys) 192.168.1.0/24(rw,no_subtree_check,sec=sys)
      /srv/nfs/the.files 10.100.0.0/24(rw,no_subtree_check,sec=sys) 192.168.1.0/24(rw,no_subtree_check,sec=sys)
    '';
  };

  systemd.tmpfiles.rules = [
    "d /srv/nfs 0755 root root -"
    "d /srv/nfs/share 0775 root root -"
  ];

  fileSystems."/srv/nfs/the.files" = {
    device = "/home/fufud/the.files";
    options = [ "bind" ];
  };

  networking.firewall.allowedTCPPorts = lib.mkAfter [ 2049 ];
  networking.firewall.allowedUDPPorts = lib.mkAfter [ 2049 ];
}
