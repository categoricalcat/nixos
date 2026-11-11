{ lib }:

let
  inherit (lib) mapAttrs' nameValuePair optionalString;

  # Canonical list of yifuwuqi services yirukou proxies; it generates both
  # proxy hops. domain/port resolve from allAddresses.hosts.yifuwuqi.services.
  # websockets defaults to true; upstreamLan fronts a backend that cannot bind
  # loopback (container-facing, or the app has no bind option), everything
  # else is loopback.
  proxiedServices = {
    attic = {
      websockets = false;
    };
    bazarr = { };
    cockpit = { };
    docs = {
      websockets = false;
    };
    files = {
      websockets = false;
    };
    forgejo = {
      websockets = false;
      bodySize = "512M";
    };
    grafana = { };
    homepage = {
      upstreamLan = true;
    };
    jellyfin = {
      upstreamLan = true;
    };
    jellyseerr = {
      upstreamLan = true;
    };
    lidarr = {
      upstreamLan = true;
    };
    opencode = {
      bodySize = "1G";
      longTimeouts = true;
    };
    pinepods = { };
    prowlarr = { };
    qbittorrent = { };
    radarr = { };
    readarr = { };
    searxng = {
      websockets = false;
    };
    sillytavern = {
      bodySize = "10M";
      longTimeouts = true;
    };
    slskd = { };
    sonarr = { };
    torrent-indexer = { };
    weather = { };
  };

  extraFor = spec: ''
    ${optionalString (spec ? bodySize) "client_max_body_size ${spec.bodySize};"}
    ${optionalString (spec.longTimeouts or false) ''
      proxy_read_timeout 1d;
      proxy_send_timeout 1d;
    ''}
  '';

  websockets = spec: spec.websockets or true;

  resolve =
    services: name:
    let
      service = services.${name};
    in
    {
      inherit (service) domain;
      port = service.port or service.httpPort;
    };
in
{
  # yirukou side: one TLS vhost per domain, all upstreams to the yifuwuqi
  # local ingress. The ingress routes on the preserved Host header.
  # recommendedProxySettings (enabled in the nginx-proxy module) already
  # includes the standard Host/X-Real-IP/X-Forwarded-* headers.
  mkRemoteVhosts =
    { allAddresses, restrictedProxyConfig }:
    let
      host = allAddresses.hosts.yifuwuqi;
      ingress = "http://${host.network.lan.ipv4.host}:${toString host.services.ingress.port}";
    in
    mapAttrs' (
      name: spec:
      let
        service = resolve host.services name;
      in
      nameValuePair service.domain {
        useACMEHost = allAddresses.baseDomain;
        forceSSL = true;
        locations."/" = {
          proxyPass = ingress;
          proxyWebsockets = websockets spec;
          extraConfig = ''
            ${extraFor spec}
            ${restrictedProxyConfig}
          '';
        };
      }
    ) proxiedServices;

  # yifuwuqi side: the local ingress. One plain-HTTP listener on the LAN
  # address, one vhost per domain proxying to the loopback backend (or the
  # LAN address for the exceptions above). X-Forwarded-* and X-Real-IP set by
  # yirukou pass through via the maps in the local-ingress module. Only
  # yirukou's LAN address may reach the listener (the firewall also enforces
  # this); a direct peer gets no forwarded identity.
  mkLocalVhosts =
    { allAddresses }:
    let
      host = allAddresses.hosts.yifuwuqi;
      lan = host.network.lan.ipv4.host;
      inherit (host.services) ingress;
      gateway = allAddresses.hosts.yirukou.network.lan.ipv4.host;
      listen = [
        {
          addr = lan;
          inherit (ingress) port;
          ssl = false;
        }
      ];
      # proxy_set_header replaces inherited headers wholesale at location
      # level, so every location spells out the standard set.
      standardHeaders = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $forwarded_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host $forwarded_host;
        proxy_set_header X-Forwarded-Proto $forwarded_proto;
      '';
    in
    mapAttrs' (
      name: spec:
      let
        service = resolve host.services name;
        upstream = if spec.upstreamLan or false then lan else "127.0.0.1";
      in
      nameValuePair service.domain {
        inherit listen;
        locations."/" = {
          proxyPass = "http://${upstream}:${toString service.port}";
          proxyWebsockets = websockets spec;
          extraConfig = ''
            ${standardHeaders}
            ${extraFor spec}
            allow ${gateway};
            deny all;
          '';
        };
      }
    ) proxiedServices
    // {
      # Reject unknown Host headers on the shared listener.
      "_" = {
        default = true;
        inherit listen;
        locations."/".return = 404;
      };
    };
}
