# Monitoring and probe topology: the probe peer ladder, the probe
# generation machinery, and the exporter/scrape/log host registry. Consumed
# via modules/addresses.nix.
{ hosts }:
let
  nodeTextfileDir = "/var/lib/prometheus-node-exporter/textfile";

  # All persistent monitoring state on the central host lives under one root
  # (grafana's DB is in postgres, see hosts.yifuwuqi.services.postgresql).
  dataRoot = "/persist/monitoring";

  # There is no IPv6 path off-net (docs/src/networking/ipv6-ula-gua.md), so
  # internet peers are probed v4-only. Flip to true once a GUA exists: the
  # mirrored v6 probes and smokeping targets come back with it.
  ipv6Egress = false;

  # The peers form a failure-domain ladder, each rung one step further out, so
  # an outage localises to the first rung that stops answering. `tier` carries
  # the rung and is numerically prefixed because Grafana sorts label values
  # lexicographically and the useful order is by distance.
  #
  # Dual-stack peers share a machine across families so the two stay
  # comparable; `v6` may be omitted for an origin that publishes no IPv6
  # address, which drops that family for the peer rather than inventing a
  # counterpart. With `ipv6Egress = false`, `lan` peers are the only ones
  # measured over both families; internet v6 comes back with the flag.
  probePeers = [
    {
      name = "yirukou";
      scope = "lan";
      tier = "1-lan";
      v4 = hosts.yirukou.network.lan.ipv4.host;
      v6 = hosts.yirukou.network.lan.ipv6.host;
      resolver = true;
    }
    {
      # Probed on this host's own LAN address, so the `dns`/`dns6` self-probe
      # crosses the local stub, the resolver hop and AdGuard in one request.
      # The host has run no Unbound since the resolver moved to yirukou.
      name = "yifuwuqi";
      scope = "lan";
      tier = "1-lan";
      v4 = hosts.yifuwuqi.network.lan.ipv4.host;
      v6 = hosts.yifuwuqi.network.lan.ipv6.host;
      resolver = true;
    }
    {
      # RedeBr AS264111, our ISP: its border interface on the IX.br Rio
      # exchange, as published in PeeringDB. Their in-path internal hops
      # answer neither echo nor TTL-exceeded, so this is the nearest
      # ISP-owned address that can be probed at all.
      name = "redebr";
      scope = "internet";
      tier = "2-isp";
      v4 = "45.68.81.57";
      v6 = "2001:12f8:0:2::53:57";
    }
    {
      # a.ntp.br (NIC.br, São Paulo). Unicast rather than anycast, so this
      # rung genuinely measures the path out of the state.
      name = "ntpbr";
      scope = "internet";
      tier = "3-country";
      v4 = "200.160.0.8";
      v6 = "2001:12ff::8";
    }
    {
      name = "cloudflare";
      scope = "internet";
      tier = "4-external";
      v4 = "1.1.1.1";
      v6 = "2606:4700:4700::1111";
      resolver = true;
      url = "https://cp.cloudflare.com";
    }
  ];

  # v4 is mandatory; v6 only exists for peers that carry an address there.
  peerFamilies = peer: [ "v4" ] ++ (if peer ? v6 then [ "v6" ] else [ ]);

  # One entry per layer: which peers it covers and how each family renders its
  # target. The blackbox module is the layer name, suffixed `6` for IPv6
  # (blackbox.yml), which is what pins the family per probe.
  probeLayers = [
    {
      layer = "icmp";
      peers = probePeers;
      v4 = peer: peer.v4;
      v6 = peer: peer.v6;
    }
    {
      layer = "dns";
      peers = builtins.filter (peer: peer.resolver or false) probePeers;
      v4 = peer: "${peer.v4}:53";
      v6 = peer: "[${peer.v6}]:53";
    }
    {
      layer = "http";
      peers = builtins.filter (peer: peer ? url) probePeers;
      # Same URL both ways.
      v4 = peer: peer.url;
      v6 = peer: peer.url;
    }
  ];
in
{
  centralHost = "yifuwuqi";
  proxyHost = "yirukou";
  inherit
    nodeTextfileDir
    dataRoot
    ipv6Egress
    probePeers
    ;
  dataDirs = {
    prometheus = "${dataRoot}/prometheus";
    loki = "${dataRoot}/loki";
    grafana = "${dataRoot}/grafana";
  };
  probes = builtins.filter (probe: ipv6Egress || probe.family == "v4" || probe.scope != "internet") (
    builtins.concatMap (
      spec:
      builtins.concatMap (
        peer:
        map (family: {
          layer = if family == "v4" then spec.layer else "${spec.layer}6";
          inherit family;
          target = spec.${family} peer;
          inherit (peer) scope tier;
          peer = peer.name;
        }) (peerFamilies peer)
      ) spec.peers
    ) probeLayers
  );
  scrapeHosts = [
    "yifuwuqi"
    "yirukou"
  ];
  logHosts = [
    "yifuwuqi"
    "yirukou"
  ];
  exporters = {
    node = {
      hosts = "scrapeHosts";
      settings = {
        enabledCollectors = [ "systemd" ];
        extraFlags = [ "--collector.textfile.directory=${nodeTextfileDir}" ];
      };
    };

    # smokeping labels its ping target `host`, which collides with our
    # origin `host` label; Prometheus renames it `exported_host`, we
    # expose it as `target`. `peer`, `scope`, `tier` and `family` are
    # derived from the target address so both families of a peer join on
    # one series set and match the blackbox labels.
    # Ping targets are per-host (a host does not ping itself), so they are
    # built in exporters.nix from `probePeers`.
    smokeping = {
      hosts = "scrapeHosts";
      settings.pingInterval = "5s";
      metricRelabelConfigs = [
        {
          source_labels = [ "exported_host" ];
          target_label = "target";
        }
      ]
      ++ builtins.concatMap (
        peer:
        let
          regex = builtins.concatStringsSep "|" (
            map (family: builtins.replaceStrings [ "." ] [ "\\." ] peer.${family}) (peerFamilies peer)
          );
        in
        map
          (label: {
            source_labels = [ "exported_host" ];
            inherit regex;
            target_label = label.name;
            replacement = label.value;
          })
          [
            {
              name = "peer";
              value = peer.name;
            }
            {
              name = "scope";
              value = peer.scope;
            }
            {
              name = "tier";
              value = peer.tier;
            }
          ]
      ) probePeers
      ++ [
        {
          source_labels = [ "exported_host" ];
          regex = "[^:]*";
          target_label = "family";
          replacement = "v4";
        }
        {
          source_labels = [ "exported_host" ];
          regex = ".*:.*";
          target_label = "family";
          replacement = "v6";
        }
        {
          regex = "exported_host";
          action = "labeldrop";
        }
      ];
    };

    # Probe jobs live in prometheus.nix (`probe` job, modules from blackbox.yml).
    blackbox = {
      hosts = "scrapeHosts";
      settings.configFile = ../services/monitoring/blackbox.yml;
    };

    systemd = {
      hosts = "scrapeHosts";
      settings.extraFlags = [
        "--systemd.collector.enable-ip-accounting"
        "--systemd.collector.enable-restart-count"
      ];
    };

    process = {
      hosts = "scrapeHosts";
      settings = {
        user = "root";
        settings.process_names = [
          {
            name = "{{.Comm}}";
            cmdline = [ ".+" ];
          }
        ];
        extraFlags = [
          "--gather-smaps=false"
          "--remove-empty-groups"
          "--threads=false"
        ];
      };
    };

    smartctl = {
      hosts = "scrapeHosts";
      scrapeInterval = "60s";
      settings.maxInterval = "5m";
    };

    nginx = {
      hosts = "proxyHost";
      settings.scrapeUri = "http://127.0.0.1/nginx_status";
    };

    fail2ban = {
      hosts = "centralHost";
      settings.exitOnError = false;
    };

    postgres.hosts = "centralHost";

    adguard = {
      hosts = "proxyHost";
    };

    unbound = {
      hosts = "proxyHost";
      settings.unbound = {
        host = "unix:///run/unbound/unbound.ctl";
        ca = null;
        certificate = null;
        key = null;
      };
    };

    # Host-local valkey. Key name must match the nixpkgs exporter module
    # (services.prometheus.exporters.redis).
    redis = {
      hosts = "scrapeHosts";
      settings = {
        # Runs as the valkey server user so it can open the unix socket
        # (owned redis:redis mode 660, under /run/redis).
        user = "redis";
        extraFlags = [
          "-redis.addr"
          "unix:///run/redis/redis.sock"
        ];
      };
    };
  };
}
