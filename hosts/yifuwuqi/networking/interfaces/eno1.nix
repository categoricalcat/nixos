# AdGuard's DoT listener validates against the ACME wildcard, and its
# `server_name` is dns.<baseDomain>. Without the name `resolved` cannot check
# the certificate, and `DNSOverTLS = "yes"` would then be unauthenticated
# encryption rather than a verified hop.
{
  addresses,
  allAddresses,
  lib,
  ...
}:
{
  systemd.network = {
    networks = {
      "30-eno1" = {
        matchConfig.Name = addresses.network.lan.interface;
        networkConfig = {
          DHCP = "no";
          # systemd.network(5) requires brackets when a port follows an IPv6
          # address, so the v6 upstream is spelled [addr]:853#name.
          DNS = map (
            addr: "${if lib.hasInfix ":" addr then "[${addr}]" else addr}:853#dns.${allAddresses.baseDomain}"
          ) addresses.dns.lanUpstreams;
          DNSOverTLS = "yes";
          Domains = [ "~." ];
          MulticastDNS = "yes";
          IPv6AcceptRA = "no";
          LinkLocalAddressing = "ipv6";
        };

        address = [
          addresses.network.lan.ipv6.address
          addresses.network.lan.ipv4.address
        ];

        # The metric-100 default route is owned exclusively by wan-monitor
        # (see ../../../../packages/gateway-failover/default.nix), which
        # withdraws it while the uplink is unhealthy, so networkd must not
        # install it. wan-monitor also pins a /32 host route to each probe
        # target via the LAN gateway, so those appearing on eno1 is expected.

        linkConfig = {
          MTUBytes = 1492;
          RequiredForOnline = "carrier";
        };
      };
    };
  };
}
