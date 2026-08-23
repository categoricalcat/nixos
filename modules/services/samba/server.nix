_:

let
  addresses = import ../../addresses.nix;
  # tailscaleCidr = addresses.hosts.yifuwuqi.network.tailscale.ipv4.cidr;
  vpnCidr = addresses.hosts.yifuwuqi.network.vpn.ipv4.cidr;
  lanCidr = addresses.hosts.yirukou.network.lan.ipv4.cidr;
in
{
  services.samba = {
    enable = true;
    openFirewall = false;
    nmbd.enable = true;

    settings = {
      global = {
        "hosts allow" = "${lanCidr} ${vpnCidr} 127.0.0.1 localhost ::1";
        "hosts deny" = "0.0.0.0/0";
        "load printers" = "no";
        "printing" = "bsd";
      };

      share = {
        path = "/srv/shares/share";
        "read only" = "no";
        "valid users" = "yi";
        "create mask" = "0664";
        "directory mask" = "0775";
      };

      "the.files" = {
        path = "/srv/shares/the.files";
        "read only" = "no";
        "valid users" = "yi";
        "create mask" = "0664";
        "directory mask" = "0775";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = false;
  };

  systemd.tmpfiles.rules = [
    "d /srv/shares 0755 root root -"
    "d /srv/shares/share 0775 yi yi -"
  ];

  fileSystems."/srv/shares/the.files" = {
    device = "/home/yi/the.files";
    fsType = "none";
    options = [ "bind" ];
  };

}
