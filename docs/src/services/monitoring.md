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
│  │  unbound, smokeping,    │     └───────────┬───────────┘  │
│  │  blackbox, smartctl)    │                               │
│  └───────────▲─────────────┘                 │              │
└──────────────┼───────────────────────────────┼──────────────┘
               │ Scrape (15s interval)         │ Ingest over LAN
┌──────────────┼───────────────────────────────┼──────────────┐
│              │                               ▼              │
│  ┌───────────┴─────────────┐     ┌───────────────────────┐  │
│  │ Prometheus Server       │     │ Loki Log Server       │  │
│  │ (30d retention, :24090) │     │ (7d retention, :24100)│  │
│  └───────────┬─────────────┘     └───────────┬───────────┘  │
│              │                               │              │
│              └───────────────┬───────────────┘              │
│                              │ Datasources                  │
│  ┌───────────────────────────▼───────────────────────────┐  │
│  │ Grafana Visualization Server (:24030)                 │  │
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

## 2. Exporter Gang & Metadata Specification

Exporters are declaratively registered in `modules/addresses.nix` under `allAddresses.monitoring.exporters` and dynamically instantiated on hosts via `modules/services/monitoring/exporters.nix`:

| Exporter           | Default Port | Target Hosts          | Scrape Interval   | Connection / Backend                              |
| ------------------ | ------------ | --------------------- | ----------------- | ------------------------------------------------- |
| **Node**           | `9100`       | `yifuwuqi`, `yirukou` | `15s`             | Systemd and textfile collectors                   |
| **Smokeping**      | `9374`       | `yifuwuqi`, `yirukou` | `15s` / `1s` ping | Continuous ICMP latency and loss                  |
| **Blackbox**       | `9115`       | `yifuwuqi`, `yirukou` | `15s`             | ICMP, UDP DNS, and HTTPS `/probe` endpoints       |
| **Systemd**        | `9558`       | `yifuwuqi`, `yirukou` | `15s`             | Monitored unit state                              |
| **Smartctl**       | `9633`       | `yifuwuqi`, `yirukou` | `60s`             | Storage drive SMART health                        |
| **Nginx**          | `9113`       | `yirukou`             | `15s`             | `http://127.0.0.1/nginx_status`                   |
| **Fail2ban**       | `9191`       | `yifuwuqi`            | `15s`             | Local jail metrics                                |
| **Postgres**       | `9187`       | `yifuwuqi`            | `15s`             | `postgres://postgres@127.0.0.1:5432/postgres`     |
| **AdGuard**        | `9617`       | `yifuwuqi`, `yirukou` | `15s`             | Custom exporter scraping AGH API (:24333 / :3333) |
| **Unbound**        | `9167`       | `yifuwuqi`, `yirukou` | `15s`             | Unix socket `/run/unbound/unbound.ctl`            |
| **Redis / Valkey** | `9121`       | `yifuwuqi`, `yirukou` | `15s`             | Unix socket `/run/redis/redis.sock`               |

Non-central hosts automatically open firewall TCP ports for all enabled exporters on the internal LAN interface with `FreeBind = true`.

### Internet Probing & Failover

Probes are generated from `probePeers` (`modules/addresses.nix`). The peers form
a **failure-domain ladder**: each rung sits one step further out, so an outage
localises to the first rung that stops answering. `tier` carries the rung and is
numerically prefixed so Grafana, which sorts label values lexicographically,
orders the series by distance:

| Peer         | Tier         | Scope      | IPv4          | IPv6                   | Layers          | RTT    |
| ------------ | ------------ | ---------- | ------------- | ---------------------- | --------------- | ------ |
| `yirukou`    | `1-lan`      | `lan`      | `10.42.0.1`   | `fd75:c55f:6d19:1::1`  | icmp, dns       | \<1 ms |
| `yifuwuqi`   | `1-lan`      | `lan`      | `10.42.0.2`   | `fd75:c55f:6d19:1::2`  | icmp, dns       | \<1 ms |
| `redebr`     | `2-isp`      | `internet` | `45.68.81.57` | `2001:12f8:0:2::53:57` | icmp            | ~3 ms  |
| `ntpbr`      | `3-country`  | `internet` | `200.160.0.8` | `2001:12ff::8`         | icmp            | ~10 ms |
| `cloudflare` | `4-external` | `internet` | `1.1.1.1`     | `2606:4700:4700::1111` | icmp, dns, http | ~11 ms |

- `redebr` is our ISP, AS264111. The probed address is its border interface on
  the IX.br Rio exchange, published in PeeringDB. RedeBr's in-path internal
  hops answer neither echo nor TTL-exceeded, so this is the nearest ISP-owned
  address that can be probed at all.
- `ntpbr` is `a.ntp.br` (NIC.br, São Paulo), unicast rather than anycast, so the
  rung genuinely measures the path out of the state.
- `cloudflare` is the external anycast baseline and the only peer carrying all
  three layers. It tests service reachability rather than geographic distance.
- IX.br **São Paulo** route servers are deliberately absent: they answer ICMP
  only from within the exchange LAN.

A peer may omit `v6` when its origin publishes no IPv6 address; that drops the
family for that peer rather than inventing a counterpart. Every peer currently
has both.

DNS peers are the resolvers (AdGuard -> Unbound on the two LAN peers, public
resolvers otherwise); HTTPS uses one URL per peer (Cloudflare's captive-portal
endpoint) with the family pinned by the blackbox module.

Smokeping sends one ICMP request to each target every 5 seconds. Prometheus
scrapes every 15 seconds, so each scrape contains roughly three new samples and
each dashboard 5-minute percentile window contains roughly 60.

Two rules trim the fan-out:

- `monitoring.ipv6Egress` is `false`, so `internet` peers are probed over IPv4
  only. There is no IPv6 path off-net
  (see [IPv6: ULA now, GUA later](../networking/ipv6-ula-gua.md)), and probing
  it would only produce permanently failing series. The `lan` peers keep both
  families, which is where the v4-vs-v6 comparison lives. Flipping the flag to
  `true` restores the mirrored internet probes and smokeping targets for peers
  that have `v6`.
- A host never probes its own peer entry, in blackbox or smokeping. Its own
  AdGuard -> Unbound chain is already measured by the `adguard` and `unbound`
  exporters, so each host probes the other host plus the internet peers: 9
  blackbox probes and 5 smokeping targets per host.

Blackbox modules (`blackbox.yml`) are named after the layer and all set
`ip_protocol_fallback: false`, so a module never silently answers over the other
family. A single `probe` scrape job fans out over host x probe; series carry
`host` (origin, same meaning as every other job), `layer`
(`icmp`/`dns`/`http`/`icmp6`/`dns6`/`http6`), `family` (`v4`/`v6`), `peer`,
`scope` (`internet`/`lan`), `tier` (the ladder rung) and `instance` (target).
`up{job="blackbox"}`
measures exporter reachability; `probe_success` measures the target. Smokeping's
target list is built per host in `exporters.nix` from the same peer table; its
native `host` label (the ping target) is relabeled to `target`, and metric
relabeling derives the same `peer`, `family`, `scope` and `tier` labels from the
address so latency panels can plot both families together and sort by rung.

`wan-notify` atomically writes `gateway_failover.prom` for the node-exporter
textfile collector. It exposes `gateway_failover_primary_active` and
`gateway_failover_last_transition_timestamp_seconds`; the node scrape adds
the source `host` label. On `yirukou`, primary means its primary WAN; on
`yifuwuqi`, it means the LAN route through `yirukou` rather than its direct
fallback.

The provisioned **Internet** dashboard is split by scope, not by family: each
panel (availability, reachability, ICMP/DNS/HTTPS duration, smokeping
percentiles and loss) plots v4 and v6 of the same peers together, with exporter
state and failover state alongside.

______________________________________________________________________

## 3. Grafana & Declarative Dashboards (`modules/services/monitoring/grafana.nix`)

- **Domain**: `https://grafana.fufu.land` (proxied to port `24030`).
- **Database Engine**: PostgreSQL socket connection (`type = "postgres"`, database `grafana`).
- **Authentication**: Form login disabled, anonymous access enabled with default `Viewer` organization role.
- **Secrets**: `services/grafana/secret-key` managed via Sops-nix.
- **Provisioned Data Sources**:
  - `Prometheus` (default, uid: `prometheus`, url: `http://127.0.0.1:24090`)
  - `Loki` (uid: `loki`, url: `http://10.42.0.2:24100`)
- **Provisioned Dashboards**:
  - **Vendored JSON Dashboards**: `adguard.json` (grafana.com 23579 rev 3) and `unbound.json` (grafana.com 21006), sanitized during Nix build with `jq` to remove stale IDs and remap datasources.
  - **Nix Declarative Dashboards**: `systemd-units.json`, `services-overview.json`, `fail2ban.json`, `prometheus.json`, `loki.json`, `grafana.json`, `postgres.json`, `valkey.json`, `internet.json`.

______________________________________________________________________

## 4. Log Shipping with Vector (`modules/services/monitoring/promtail.nix`)

Log shipping uses **Vector** (`services.vector`):

- **Source**: `sources.journald.type = "journald"` with full systemd journal access.
- **Sink**: `sinks.loki.type = "loki"` pointing to `http://10.42.0.2:24100`.
- **Labels Attached**: `host = <hostName>`, `job = "systemd-journal"`.

______________________________________________________________________

## 5. Key Source Files

- `modules/services/monitoring/prometheus.nix`
- `modules/services/monitoring/grafana.nix`
- `modules/services/monitoring/loki.nix`
- `modules/services/monitoring/promtail.nix`
- `modules/services/monitoring/exporters.nix`
- `modules/services/monitoring/blackbox.yml`
- `modules/services/monitoring/adguard-exporter/`
- `modules/services/monitoring/dashboards/`
