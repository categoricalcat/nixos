{
  addresses,
  lib,
  ...
}:

let
  inherit (addresses.network) lan untrusted wan;
  internalInterfaces = [
    lan.interface
    untrusted.interface
  ];
  wanInterfaces = [
    wan.primary.interface
    wan.fallback.interface
  ];
  nftStringSet = values: lib.concatStringsSep ", " (map (value: ''"${value}"'') values);
  internalSet = nftStringSet internalInterfaces;
  wanSet = nftStringSet wanInterfaces;
in
{
  networking = {
    firewall = {
      enable = true;
      backend = "nftables";
      filterForward = true;
      allowPing = true;
      interfaces = {
        ${lan.interface}.allowedUDPPorts = [ 67 ]; # DHCPv4
        ${untrusted.interface}.allowedUDPPorts = [ 67 ]; # DHCPv4
      };
      extraForwardRules = ''
        iifname "${lan.interface}" oifname { ${wanSet} } accept comment "lan to wan"
        iifname "${untrusted.interface}" oifname { ${wanSet} } accept comment "untrusted to wan"
      '';
    };

    nftables = {
      enable = true;
      tables.yirukou-nat = {
        family = "ip";
        content = ''
          chain post {
            type nat hook postrouting priority srcnat; policy accept;

            iifname { ${internalSet} } oifname { ${wanSet} } masquerade
          }
        '';
      };
    };
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
}
