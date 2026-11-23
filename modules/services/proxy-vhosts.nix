{
  lib,
  config,
  ...
}:

let
  inherit (lib)
    filterAttrs
    mapAttrs'
    nameValuePair
    optionalAttrs
    optionalString
    ;

  cfg = config.yi.mtls;
  hostName = config.networking.hostName;
  monitoringLib = import ./monitoring/lib.nix;

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

  # nginx inherits neither the certificate nor client verification from the
  # default server sharing a listen socket, so every vhost repeats them.
  # `verify` selects which peer identity that vhost admits.
  serverTls =
    verify:
    optionalAttrs cfg.enable {
      addSSL = true;
      sslCertificate = cfg.serverCert;
      sslCertificateKey = cfg.serverKey;
      extraConfig = verify;
    };

  # One path-prefixed location per registry exporter enabled on this host, so
  # the single ingress port serves them all. The same registry drives the
  # scrape jobs, so exporter ports live in one place. `/<name>/` maps onto the
  # exporter root, which makes the scrape path `/<name>/metrics`.
  #
  # A host that does not import the exporters module has no options at all,
  # and the ingress must still evaluate there: the DR drill imports this module
  # precisely that way.
  exporterEnabled =
    name:
    config.services.prometheus.exporters ? ${name}
    && config.services.prometheus.exporters.${name}.enable;

  mkExporterLocations =
    { allAddresses, accessConfig }:
    mapAttrs' (
      name: _:
      nameValuePair "/${name}/" {
        proxyPass = "http://127.0.0.1:${toString config.services.prometheus.exporters.${name}.port}/";
        extraConfig = accessConfig;
      }
    ) (filterAttrs (name: _: exporterEnabled name) allAddresses.monitoring.exporters);

  # The default vhost of an ingress listener. Prometheus and Vector cannot set
  # Host, so their requests land here; it carries the TLS material and the
  # machine paths, and 404s everything else.
  mkMachineVhost =
    {
      allAddresses,
      accessConfig,
      extraLocations ? { },
    }:
    let
      host = allAddresses.hosts.${hostName};
    in
    {
      default = true;
      listen = [
        {
          addr = host.network.lan.ipv4.host;
          port = host.services.ingress.port;
          ssl = cfg.enable;
        }
      ];
      locations =
        mkExporterLocations { inherit allAddresses accessConfig; }
        // extraLocations
        // {
          "/".return = 404;
        };
    }
    // serverTls cfg.machineVerify;
in
{
  inherit mkMachineVhost;

  # yirukou side: one vhost per domain, all upstreams to the yifuwuqi ingress
  # over mTLS. The ingress routes on the preserved Host header.
  # recommendedProxySettings (enabled in the nginx-proxy module) already
  # includes the standard Host/X-Real-IP/X-Forwarded-* headers.
  mkRemoteVhosts =
    { allAddresses, restrictedProxyConfig }:
    let
      host = allAddresses.hosts.yifuwuqi;
      scheme = if cfg.enable then "https" else "http";
      ingress = "${scheme}://${monitoringLib.ingressAddress host}";
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
            ${optionalString cfg.enable cfg.upstreamTls}
          '';
        };
      }
    ) proxiedServices;

  # yifuwuqi side: the local ingress. One listener on the LAN address, one
  # vhost per domain proxying to the loopback backend (or the LAN address for
  # the exceptions above). X-Forwarded-* and X-Real-IP set by yirukou pass
  # through via the maps in the local-ingress module. The peer's client
  # certificate is the identity; the address allowlist is defence in depth.
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
          ssl = cfg.enable;
        }
      ];
      # Machine paths answer this host (self-scraping its own LAN address) and
      # the gateway, which pushes logs and reads metrics over the same vhost.
      machineAccess = ''
        allow ${lan};
        allow ${gateway};
        deny all;
      '';
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
      nameValuePair service.domain (
        {
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
        // serverTls cfg.serverVerify
      )
    ) proxiedServices
    // {
      # Unknown Host headers land on the default vhost; the machine-scrape
      # paths and the Loki push path live there.
      "_" = mkMachineVhost {
        inherit allAddresses;
        accessConfig = machineAccess;
        extraLocations."/loki/" = {
          proxyPass = "http://127.0.0.1:${toString host.services.loki.port}/";
          extraConfig = machineAccess;
        };
      };
    };
}
