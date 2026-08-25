# Monitoring & Observability Stack

The infrastructure runs a centralized Prometheus, Grafana, Loki, and Vector monitoring stack for real-time metrics collection, dashboard visualization, and structured journal log indexing.

______________________________________________________________________

## 1. Monitoring Topology

```text
┌─────────────────────────────────────────────────────────────┐
│                       yirukou (Edge Router)                 │
│  ┌─────────────────────────┐     ┌───────────────────────┐  │
│  │ Local Exporters         │     │ Vector Agent          │  │
│  │ (node, nginx, adguard,  │     │ (ships journald logs) │  │
│  │  unbound, smartctl)     │     └───────────┬───────────┘  │
│  └───────────▲─────────────┘                 │              │
└──────────────┼───────────────────────────────┼──────────────┘
               │ Scrape (15s interval)         │ Ingest over LAN
┌──────────────┼───────────────────────────────┼──────────────┐
│              │                               ▼              │
│  ┌───────────┴─────────────┐     ┌───────────────────────┐  │
│  │ Prometheus Server       │     │ Loki Log Server       │  │
│  │ (30d retention, :9090)  │     │ (7d retention, :3100) │  │
│  └───────────┬─────────────┘     └───────────┬───────────┘  │
│              │                               │              │
│              └───────────────┬───────────────┘              │
│                              │ Datasources                  │
│  ┌───────────────────────────▼───────────────────────────┐  │
│  │ Grafana Visualization Server (:3000)                  │  │
│  │ • PostgreSQL Backend                                  │  │
│  │ • Declarative JSON / Nix Provisioned Dashboards       │  │
│  │ • Anonymous Viewer Access                             │  │
│  └───────────────────────────────────────────────────────┘  │
│                    yifuwuqi (Core Server)                   │
└─────────────────────────────────────────────────────────────┘
```

- **Central Host (`yifuwuqi`)**: Hosts the storage engines (Prometheus, Loki, PostgreSQL), Grafana UI, and central scrapers.
- **Scrape Hosts (`yirukou`, `yifuwuqi`)**: Monitored endpoints exposing Prometheus exporter ports across the trusted LAN.
- **Log Shipping**: Vector agents on each host stream systemd journal entries directly to Loki over HTTP.

______________________________________________________________________

## 2. Exporter Fleet & Metadata Specification

Exporters are declaratively registered in `modules/addresses.nix` under `allAddresses.monitoring.exporters` and dynamically instantiated on hosts via `modules/services/monitoring/exporters.nix`:

| Exporter           | Default Port | Target Hosts          | Scrape Interval | Connection / Backend                          |
| ------------------ | ------------ | --------------------- | --------------- | --------------------------------------------- |
| **Node**           | `9100`       | `yifuwuqi`, `yirukou` | `15s`           | Systemd collectors enabled                    |
| **Systemd**        | `9558`       | `yifuwuqi`, `yirukou` | `15s`           | Monitored unit state                          |
| **Smartctl**       | `9633`       | `yifuwuqi`, `yirukou` | `60s`           | Storage drive SMART health                    |
| **Nginx**          | `9113`       | `yirukou`             | `15s`           | `http://127.0.0.1/nginx_status`               |
| **Fail2ban**       | `9191`       | `yifuwuqi`            | `15s`           | Local jail metrics                            |
| **Postgres**       | `9187`       | `yifuwuqi`            | `15s`           | `postgres://postgres@127.0.0.1:5432/postgres` |
| **AdGuard**        | `9617`       | `yifuwuqi`, `yirukou` | `15s`           | Custom exporter scraping AGH API (:3333)      |
| **Unbound**        | `9167`       | `yifuwuqi`, `yirukou` | `15s`           | Unix socket `/run/unbound/unbound.ctl`        |
| **Redis / Valkey** | `9121`       | `yifuwuqi`            | `15s`           | Unix socket `/run/redis/redis.sock`           |

Non-central hosts automatically open firewall TCP ports for all enabled exporters on the internal LAN interface with `FreeBind = true`.

______________________________________________________________________

## 3. Grafana & Declarative Dashboards (`modules/services/monitoring/grafana.nix`)

- **Domain**: `https://grafana.fufu.land` (proxied to port `3000`).
- **Database Engine**: PostgreSQL socket connection (`type = "postgres"`, database `grafana`).
- **Authentication**: Form login disabled, anonymous access enabled with default `Viewer` organization role.
- **Secrets**: `services/grafana/secret-key` managed via Sops-nix.
- **Provisioned Data Sources**:
  - `Prometheus` (default, uid: `prometheus`, url: `http://127.0.0.1:9090`)
  - `Loki` (uid: `loki`, url: `http://10.42.0.2:3100`)
- **Provisioned Dashboards**:
  - **Vendored JSON Dashboards**: `adguard.json` (grafana.com 23579 rev 3) and `unbound.json` (grafana.com 21006), sanitized during Nix build with `jq` to remove stale IDs and remap datasources.
  - **Nix Declarative Dashboards**: `systemd-units.json`, `services-overview.json`, `fail2ban.json`, `prometheus.json`, `loki.json`, `grafana.json`, `postgres.json`, `valkey.json`.

______________________________________________________________________

## 4. Log Shipping with Vector (`modules/services/monitoring/promtail.nix`)

Log shipping uses **Vector** (`services.vector`):

- **Source**: `sources.journald.type = "journald"` with full systemd journal access.
- **Sink**: `sinks.loki.type = "loki"` pointing to `http://10.42.0.2:3100`.
- **Labels Attached**: `host = <hostName>`, `job = "systemd-journal"`.

______________________________________________________________________

## 5. Key Source Files

- `modules/services/monitoring/prometheus.nix`
- `modules/services/monitoring/grafana.nix`
- `modules/services/monitoring/loki.nix`
- `modules/services/monitoring/promtail.nix`
- `modules/services/monitoring/exporters.nix`
- `modules/services/monitoring/adguard-exporter/`
- `modules/services/monitoring/dashboards/`
