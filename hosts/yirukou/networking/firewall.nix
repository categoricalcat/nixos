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
  internalTcpPorts = [
    53
    80
    443
    853
  ];
  internalUdpPorts = [
    53
    67 # DHCPv4
    853
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
        ${lan.interface} = {
          allowedTCPPorts = internalTcpPorts;
          allowedUDPPorts = internalUdpPorts;
        };
        ${untrusted.interface} = {
          allowedTCPPorts = internalTcpPorts;
          allowedUDPPorts = internalUdpPorts;
        };
        ${wan.primary.interface} = {
          allowedTCPPorts = [
            80
            443
            853
          ];
          allowedUDPPorts = [ 853 ];
        };
        ${wan.fallback.interface} = {
          allowedTCPPorts = [
            80
            443
            853
          ];
          allowedUDPPorts = [ 853 ];
        };
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
