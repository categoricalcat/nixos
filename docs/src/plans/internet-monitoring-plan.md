# Internet Uptime & Latency Monitoring Plan (yifuwuqi + yirukou)

Goal: measure internet uptime, latency, packet loss, and per-layer
reachability (ICMP / DNS / HTTP) in Grafana, probing from both hosts so
LAN-side problems can be distinguished from ISP-side problems. Surface
keepalived WAN-failover state as a metric for correlation.

Decisions:

- `smokeping_prober` for continuous fine-grained latency/loss (1s ICMP,
  histograms) plus `blackbox_exporter` for layered uptime probes at scrape
  resolution.
- Probe from both `yifuwuqi` and `yirukou`.
- keepalived stays a failover mechanism only. nixpkgs has no keepalived
  exporter and keepalived exposes no metrics; instead the existing
  `wan-notify` script writes a node_exporter textfile metric.

## Verified repository state

1. Central monitoring stack runs on `yifuwuqi`: Prometheus (:24090, 15s
   scrape), Loki, Grafana (:24030), PostgreSQL. `yirukou` is the edge
   router. Both are `monitoring.scrapeHosts`.
1. Exporters are declaratively registered in `modules/addresses.nix` under
   `monitoring.exporters` and instantiated by
   `modules/services/monitoring/exporters.nix`: central host listens on
   `127.0.0.1`, others on the LAN IP with firewall port opened and
   `FreeBind = true`. `modules/services/monitoring/prometheus.nix` generates
   one scrape job per exporter via `mkScrapeConfig` (plain `/metrics`
   scrapes only — unsuitable for blackbox probe jobs).
1. nixpkgs provides modules for all three candidates:
   `services.prometheus.exporters.smokeping` (:9374, `hosts` list, 1s
   default interval, CAP_NET_RAW handled),
   `services.prometheus.exporters.blackbox` (:9115, requires `configFile`),
   `services.prometheus.exporters.ping` (not used).
1. Both hosts import `modules/networking/gateway-failover.nix` (keepalived).
   It pings `216.239.35.0` and `200.160.0.8` via the primary uplink every 2s
   and flips the default route on MASTER/FAULT transitions through
   `wan-notify`, which already tracks gateway changes in
   `/run/gateway-failover-active-gw`.
1. Existing DNS monitoring (unbound + adguard exporters) reads server
   internals only; no end-to-end resolution probe exists.
1. Grafana dashboards are provisioned from
   `modules/services/monitoring/dashboards/`: vendored JSON sanitized with
   jq, plus Nix-declared dashboards imported in
   `modules/services/monitoring/grafana.nix` (`dashboardDir`).
1. `monitoring.exporters.node` enables the `systemd` collector only; no
   textfile collector directory is configured.

## Design

- Shared probe target data lives in `modules/addresses.nix` under
  `monitoring.probes` so smokeping and blackbox stay in sync:

  - `icmp`: `1.1.1.1`, `8.8.8.8`, `216.239.35.0`, `200.160.0.8` (reuses the
    failover anchors: Google time + registro.br).
  - `dns`: external resolvers (`1.1.1.1`, `8.8.8.8`) and each host's local
    resolver for end-to-end resolution checks.
  - `http`: `https://www.google.com/generate_204`,
    `https://cp.cloudflare.com` (catch "ping works, web broken": transparent
    proxies, MTU/TLS faults; measures full TLS handshake latency).

- smokeping fits the existing exporter registry (`settings.hosts` =
  `monitoring.probes.icmp`); blackbox does not (needs a pkgs-generated
  config file and custom scrape jobs), so it gets a dedicated module
  mirroring `exporters.nix` listen/firewall conventions.

- Failover state metric written atomically by `wan-notify`:

  ```text
  gateway_failover_primary_active{interface="...",gateway="..."} 0|1
  gateway_failover_last_transition_timestamp_seconds NNN
  ```

## Implementation steps

1. `modules/addresses.nix`
   - Add `monitoring.probes` (icmp/dns/http lists as above).
   - Register `smokeping = { hosts = "scrapeHosts"; settings.hosts = monitoring.probes.icmp; }` in `monitoring.exporters`.
   - Extend the `node` entry with `settings.extraFlags = [ "--collector.textfile.directory=/var/lib/prometheus-node-exporter/textfile" ]`.
1. New `modules/services/monitoring/blackbox.nix`
   - Enable `services.prometheus.exporters.blackbox` with a generated
     `configFile` defining modules `icmp`, `dns_udp` (known-good query,
     expect NOERROR), `http_2xx`, `http_204`.
   - Listen address, LAN firewall port, and `FreeBind` follow the
     `exporters.nix` central/non-central logic.
   - Import in `hosts/yifuwuqi/services.nix` and
     `hosts/yirukou/services.nix`.
1. `modules/services/monitoring/prometheus.nix`
   - Helper generating one scrape job per (probe host × blackbox module):
     `params.module`, relabel `__param_target` ← target, `instance` ←
     target, `__address__` ← that host's blackbox `:9115`, plus `host`
     label. Targets come from `monitoring.probes`.
1. `modules/networking/gateway-failover.nix`
   - `wan-notify` writes the textfile metrics (tmp file + `mv`) on every
     state transition.
   - `systemd.tmpfiles` rule creates
     `/var/lib/prometheus-node-exporter/textfile` (root-owned,
     world-readable).
1. New `modules/services/monitoring/dashboards/internet.nix`, registered in
   `grafana.nix` `dashboardDir`. Panels:
   - Uptime % per layer/target/host: `avg_over_time(probe_success[24h])`.
   - State timeline: `probe_success` per module and
     `gateway_failover_primary_active` (failover annotations).
   - Latency: smokeping p50/p95/p99 via `histogram_quantile` on
     `smokeping_response_duration_seconds`, packet loss = `1 - rate(..._count) / rate(smokeping_requests_total)`, blackbox
     `probe_duration_seconds` for DNS/HTTP.
1. `docs/src/services/monitoring.md`
   - Add smokeping (:9374) and blackbox (:9115) rows to the exporter table
     plus a short probing section.

## Rollout & verification

1. `nix build` the toplevel for both hosts.
1. Deploy `yifuwuqi` locally; hand the `yirukou` rebuild command to the
   operator (no `--target-host` per ai-ssh policy).
1. Verify all new targets are `up` in Prometheus, smokeping/blackbox series
   are flowing from both hosts, and the Internet dashboard renders.
1. Failover metric appears after the next keepalived transition or a
   keepalived restart; confirm with
   `curl <host>:9100/metrics | grep gateway_failover`.
