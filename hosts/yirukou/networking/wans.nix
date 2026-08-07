{
  addresses,
  pkgs,
  lib,
  ...
}:

let
  inherit (addresses.network.wan) primary fallback;
  inherit (addresses.network.lan) interface ports;
in
{
  systemd.network.networks = {
    "10-${primary.interface}" = {
      matchConfig.Name = primary.interface;
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = "yes";
      };
      dhcpV4Config = {
        RouteMetric = primary.routeMetric;
        UseDNS = true;
        UseRoutes = false;
      };
      linkConfig.RequiredForOnline = "routable";
    };

    "11-${fallback.interface}" = {
      matchConfig.Name = fallback.interface;
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = "yes";
      };
      dhcpV4Config = {
        RouteMetric = fallback.routeMetric;
        UseDNS = true;
        UseRoutes = false;
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };

  systemd.services.tailscale-udp-gro = {
    description = "Enable UDP GRO forwarding for Tailscale";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.ethtool}/bin/ethtool -K ${primary.interface} rx-udp-gro-forwarding on rx-gro-list off || true
      ${pkgs.ethtool}/bin/ethtool -K ${fallback.interface} rx-udp-gro-forwarding on rx-gro-list off || true
      ${pkgs.ethtool}/bin/ethtool -K ${interface} rx-udp-gro-forwarding on rx-gro-list off || true
      ${lib.concatMapStringsSep "\n" (
        port: "${pkgs.ethtool}/bin/ethtool -K ${port} rx-udp-gro-forwarding on rx-gro-list off || true"
      ) ports}
    '';
  };
}
