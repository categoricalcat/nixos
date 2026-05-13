{
  addresses,
  lib,
  ...
}:

let
  inherit (addresses.network) lan untrusted;
  dnsServers = lib.concatStringsSep ", " addresses.dns.lanServers;
in
{
  services.kea.dhcp4 = {
    enable = true;
    settings = {
      valid-lifetime = 4000;
      renew-timer = 1000;
      rebind-timer = 2000;
      interfaces-config = {
        interfaces = [
          lan.interface
          untrusted.interface
        ];
        service-sockets-require-all = false;
        service-sockets-max-retries = 60;
        service-sockets-retry-wait-time = 1000;
      };
      lease-database = {
        type = "memfile";
        persist = true;
        name = "/var/lib/kea/dhcp4.leases";
      };
      subnet4 = [
        {
          id = 1;
          subnet = lan.ipv4.cidr;
          pools = [
            { pool = lan.dhcp.pool.range; }
          ];
          option-data = [
            {
              name = "routers";
              data = lan.ipv4.host;
            }
            {
              name = "domain-name-servers";
              data = dnsServers;
            }
          ];
        }
        {
          id = untrusted.vlanId;
          subnet = untrusted.ipv4.cidr;
          pools = [
            { pool = untrusted.dhcp.pool.range; }
          ];
          option-data = [
            {
              name = "routers";
              data = untrusted.ipv4.host;
            }
            {
              name = "domain-name-servers";
              data = dnsServers;
            }
          ];
        }
      ];
    };
  };
}
