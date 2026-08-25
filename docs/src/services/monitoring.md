# Monitoring

The monitoring stack runs a Prometheus/Grafana/Loki stack for metrics, dashboards, and logs.

## Current Status

| Module | Status | Role |
| --- | --- | --- |
| `prometheus.nix` | Implemented | Central time-series metrics server on `yifuwuqi`. |
| `grafana.nix` | Implemented | Dashboards and provisioned Prometheus/Loki datasources. Declarative dashboards via Nix. |
| `loki.nix` | Implemented | Central log aggregation server on `yifuwuqi`. |
| `promtail.nix` | Implemented | Vector-based journald shipper. |
| `alertmanager.nix` | Placeholder | Future alert routing. |
| `exporters.nix` | Implemented | Node, systemd, smartctl, nginx, fail2ban, postgres, AdGuard Home, and Unbound exporters. |

## Topology

Prometheus/Grafana/Loki deployment:

- Central host, proxy host, scrape hosts, and log hosts are defined in
  `modules/addresses.nix` under `monitoring`.
- The central host runs Prometheus, Loki, Grafana, local exporters, and Vector.
- The proxy host runs nginx, exporters, and Vector.
- Prometheus scrape jobs are generated from `exporter-metadata.nix`.
- Vector on each log host pushes journald logs to Loki with a `host` label.
- `grafana.fufu.land` is served by nginx on the proxy host and proxies to the
  central host's Grafana endpoint.

## Operational Notes

Prometheus/Grafana/Loki is configured with:

- Prometheus retention: 30 days.
- Loki retention: 7 days.
- Grafana datasource provisioning for Prometheus and Loki.
- Grafana dashboards are fully provisioned declaratively from `modules/services/monitoring/dashboards` (hybrid of vendored JSON and custom Nix attrsets).
- Vendored dashboards include `adguard.json` (grafana.com 23579, classic-schema revision 3 — later revisions use the v2 dashboard API that file provisioning cannot import) and `unbound.json` (grafana.com 21006), fed by the per-host `adguard`/`unbound` exporter jobs with `instance=<host>` labels.
- The AdGuard exporter (`modules/services/monitoring/adguard-exporter/`, module `default.nix` + package `package.nix`) scrapes the local AGH API (`:3333`, dummy Basic auth — AGH auth is disabled, VPN-only exposure) on port 9617. The vendored dashboard's ISP/GeoIP panels were removed: the exporter only resolves ISP/geo for public client IPs, and every querylog client is private (LAN/Tailscale/containers), so those panels can never render.
- The Unbound exporter (nixpkgs `services.prometheus.exporters.unbound`) connects over the local control socket `/run/unbound/unbound.ctl`; unbound runs with `extended-statistics` for recursion-time percentiles and per-type counters.
- The Valkey exporter (nixpkgs `services.prometheus.exporters.redis`, port 9121) runs only on the central host and reaches the shared valkey over its unix socket `/run/redis/redis.sock` (same-host local connection). The custom `valkey.json` dashboard shows the DNS cache (db0): entry count, keys with expirations, hit ratio, memory vs the 1 GiB max, and eviction/expiry rates.
- Grafana uses anonymous Viewer access; only the required `secret_key` is a
  SOPS secret referenced through Grafana's file provider.
- Remote exporter ports are opened on the LAN interface for scrape hosts.
- Promtail is not used; local nixpkgs removed it after EOL, so Vector ships
  journald logs via structured Nix settings.

## Source Files

- `modules/services/monitoring/exporter-metadata.nix`
- `modules/services/monitoring/prometheus.nix`
- `modules/services/monitoring/grafana.nix`
- `modules/services/monitoring/dashboards/`
- `modules/services/monitoring/loki.nix`
- `modules/services/monitoring/promtail.nix`
- `modules/services/monitoring/exporters.nix`
- `modules/services/monitoring/adguard-exporter/`
- `modules/services/monitoring/dashboards/vendor/adguard.json`
- `modules/services/monitoring/dashboards/vendor/unbound.json`
- `modules/services/monitoring/dashboards/valkey.nix`
- `hosts/yirukou/services.nix`
- `hosts/yifuwuqi/services.nix`
- `modules/services/nginx-proxy.nix`
