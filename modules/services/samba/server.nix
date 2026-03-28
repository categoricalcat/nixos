_:

let
  tailscaleCidr = "100.64.0.0/10";
  zeroCidr = "10.0.0.0/24";
in
{
  services.samba = {
    enable = true;
    nmbd.enable = true;

    settings = {
      global = {
        "hosts allow" = "${tailscaleCidr} ${zeroCidr} 127.0.0.1 localhost ::1";
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
    options = [ "bind" ];
  };
}
