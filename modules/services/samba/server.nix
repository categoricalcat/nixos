{ config, lib, ... }:

let
  vpnCidr = "10.100.0.0/24";
  vpnInterface = "wg0";
in
{
  services.samba = {
    enable = true;
    nmbd.enable = true;

    settings = {
      global = {
        "hosts allow" = "${vpnCidr} 127.0.0.1 localhost ::1";
        "hosts deny" = "0.0.0.0/0";
        "load printers" = "no";
        "printing" = "bsd";
      };

      share = {
        path = "/srv/nfs/share";
        "read only" = "no";
        "valid users" = "fufud root";
        "create mask" = "0664";
        "directory mask" = "0775";
      };

      "the.files" = {
        path = "/srv/nfs/the.files";
        "read only" = "no";
        "valid users" = "fufud root";
        "create mask" = "0664";
        "directory mask" = "0775";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = false; # We open ports on VPN interface only below
  };

  warnings =
    lib.optional (!config.sops.secrets ? "samba/credentials/fufud")
      "Run `sudo smbpasswd -a fufud` on the server to activate Samba passwords for existing Unix users.";

  networking.firewall.interfaces.${vpnInterface} = {
    allowedTCPPorts = lib.mkAfter [
      139
      445
      5357 # wsdd
    ];
    allowedUDPPorts = lib.mkAfter [
      137
      138
      3702 # wsdd
    ];
  };

}

