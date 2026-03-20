_:

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
    openFirewall = false;
  };

  # SMB ports on ZeroTier — zt+ wildcard doesn't translate to nftables zt*,
  # so trustedInterfaces alone won't open these ports on ZeroTier interfaces.
  networking.firewall.extraInputRules = ''
    iifname "zt*" tcp dport { 139, 445 } accept
    iifname "zt*" udp dport { 137, 138 } accept
  '';
}
