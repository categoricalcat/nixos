{ addresses, ... }:

{
  systemd.network = {
    networks = {
      # Fallback uplink. UseRoutes=false so networkd never installs a default
      # route here - keepalived owns the default route on both transitions
      # (see modules/networking/gateway-failover.nix). The interface still
      # gets an IP and DHCP lease info, which is what discover_lease reads.
      "35-enp4s0" = {
        matchConfig.Name = addresses.network.secondary.interface;
        networkConfig = {
          DHCP = "ipv4";
          DNS = addresses.dns.systemNameservers;
          MulticastDNS = "yes";
          IPv6AcceptRA = "no";
          LinkLocalAddressing = "no";
        };

        dhcpV4Config = {
          UseDNS = false;
          UseRoutes = false;
        };

        linkConfig = {
          MTUBytes = 1500;
          RequiredForOnline = "no";
        };
      };
    };
  };
}
