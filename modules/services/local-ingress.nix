{ allAddresses, lib, ... }:

let
  proxyLib = import ./proxy-vhosts.nix { inherit lib; };
in
{
  # One nginx listener on the LAN address fronts every proxied backend;
  # backends bind loopback (exceptions keep the LAN address). Plain HTTP
  # until mTLS Tier 2 adds the server certificate and client verification
  # here.
  services.nginx = {
    enable = true;
    serverTokens = false;

    # X-Forwarded-* / X-Real-IP set by yirukou pass through; a direct request
    # falls back to this hop's own values so a non-gateway peer cannot forge a
    # client identity.
    appendHttpConfig = ''
      map $http_x_forwarded_proto $forwarded_proto {
        default $http_x_forwarded_proto;
        ''' $scheme;
      }
      map $http_x_forwarded_host $forwarded_host {
        default $http_x_forwarded_host;
        ''' $host;
      }
      map $http_x_real_ip $forwarded_addr {
        default $http_x_real_ip;
        ''' $remote_addr;
      }
    '';

    virtualHosts = proxyLib.mkLocalVhosts { inherit allAddresses; };
  };

  # The listener binds the LAN address, which may not exist until the link is
  # up; the module default only orders after network.target.
  systemd.services.nginx = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
