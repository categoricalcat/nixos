{ config, lib, ... }:

let
  vpnCidr = "10.100.0.0/24";
  zeroCidr = "10.0.0.0/24";
in
{
  services.samba = {
    enable = true;
    nmbd.enable = true;

    settings = {
      global = {
        "hosts allow" = "${vpnCidr} ${zeroCidr} 127.0.0.1 localhost ::1";
        "hosts deny" = "0.0.0.0/0";
        "load printers" = "no";
        "printing" = "bsd";
      };

      share = {
        path = "/srv/nfs/share";
        "read only" = "no";
        "valid users" = "yi";
        "create mask" = "0664";
        "directory mask" = "0775";
      };

      "the.files" = {
        path = "/srv/nfs/the.files";
        "read only" = "no";
        "valid users" = "yi";
        "create mask" = "0664";
        "directory mask" = "0775";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = false; # We open ports on VPN interface only below
  };

  warnings = lib.optional (
    !config.sops.secrets ? "samba/credentials/yi"
  ) "Run `sudo smbpasswd -a yi` on the server to activate Samba passwords for existing Unix users.";

  sops.secrets."samba/credentials/yi" = {
    mode = "0600";
    path = "/etc/samba/credentials/yi";
  };
}
