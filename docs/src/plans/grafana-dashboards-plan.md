# Declarative Grafana Dashboards Plan [IMPLEMENTED]

## Goal

Provision Grafana dashboards fully declaratively for all monitored services on
`yifuwuqi` and `yirukou`, matching the existing style in
`modules/services/monitoring/`.

## Design

Grafana is already provisioned (`modules/services/monitoring/grafana.nix`) with
datasources via `provision.datasources`. We extend the same mechanism with a
**hybrid content strategy**:

- **Big, battle-tested dashboards are vendored as JSON** from grafana.com
  (deterministic, diffable, no build-time network). Hand-writing a 31-panel
  host board as Nix attrsets is wasted effort against a 141M-download
  community dashboard.
- **Small, host-specific dashboards are authored as Nix attrsets** rendered
  with `builtins.toJSON` — no grafonnet/jsonnet dependency, full control where
  it is cheap.
- Both sources are assembled into a store directory and provisioned through a
  single `file` provider.

Community Nix DSLs for dashboards (`mkg/grafana-dashboards`,
`amadejkastelic/nix-grafana-dashboards`) were researched and are **dead**
(repo 404); `blackheaven/grafana-dashboards.nix` is stale (2023). Not used.

### File layout

```
modules/services/monitoring/dashboards/
├── lib.nix                # panel builders (mkTimeseries, mkStat, mkGauge, grid pos) for custom boards
├── systemd-units.nix      # custom: node_systemd_unit_state, failed/degraded, restarts
├── services-overview.nix  # custom: per-service unit-state grid for main app services
├── fail2ban.nix           # custom: per-jail banned IPs, ban rate
├── prometheus.nix         # custom: scrape health, TSDB stats, samples ingested
├── loki.nix               # custom: request/ingestion rates from Loki /metrics
├── grafana.nix            # custom: Grafana self-metrics
├── postgres.nix           # custom: pg_stat via postgres_exporter
└── vendor/
    ├── node-exporter-full.json   # grafana.com 1860  (rev 45, updated 2026-04)
    ├── smartctl.json             # grafana.com 22604 (rev 3,  updated 2026-07)
    └── nginx.json                # grafana.com 12708 (rev 1,  updated 2020)
```

### Provisioning

In `grafana.nix`, assemble the dashboard directory with `pkgs.runCommand`:
copy the vendored JSONs (stripping the `id` field via `jq del(.id)`, per
[Grafana provisioning docs](https://grafana.com/docs/grafana/latest/administration/provisioning/)),
also stripping `__inputs` and resolving `${DS_PROMETHEUS}` datasource
placeholders to the provisioned Prometheus datasource uid (the file provider
does not substitute `__inputs` — only the UI import flow does),
plus the `writeText`-rendered custom boards, then add:

```nix
provision.dashboards.settings.providers = [
  {
    name = "declarative";
    options.path = <assembled dir>;
  }
];
```

- Every dashboard gets a stable `uid` (custom ones set explicitly; vendored
  ones ship theirs). Provisioned boards are read-only in the UI — desired.
- `disableDeletion` stays default (false): removing a JSON file removes the
  dashboard, keeping the store dir the source of truth.
- `foldersFromFilesStructure = false`; all boards land at the root level.

### Scrape additions (`prometheus.nix`)

1. **Relabel `host` → `instance`** in `mkScrapeConfig`: vendored SMART/nginx
   dashboards template on `instance`, so series show `yifuwuqi`/`yirukou`
   instead of `10.42.0.2:9633`. (Node Exporter Full uses its own `nodename`
   variable and works either way.)
2. **Loki self-metrics**: scrape `http://<central LAN IP>:3100/metrics`.
   Note: Loki binds `http_listen_address` to the **LAN address**, not
   `127.0.0.1` — target must use `10.42.0.2`.
3. **Grafana self-metrics**: scrape `http://<central LAN IP>:3030/metrics`
   (Grafana exposes `/metrics` unauthenticated by default). Same LAN-address
   note (`http_addr = 10.42.0.2`).
4. Prometheus already scrapes itself.

### Postgres exporter (only new exporter in scope)

- `modules/addresses.nix`: add `postgres = { hosts = "centralHost"; }` under
  `monitoring.exporters` with
  `settings.dataSourceName = "postgres://postgres@127.0.0.1:5432/postgres?sslmode=disable"`.
  `exporters.nix` `serviceAvailable` default-true branch already handles it.
- **`modules/services/postgresql.nix`**: the `authentication` override replaces
  the nixpkgs default pg_hba entirely (only `10.42.0.0/24 trust` remains), so
  add `host all all 127.0.0.1/32 trust` (or restrict to the postgres user)
  for the exporter's localhost connection.

## Dashboards to add

| Board | Source | Hosts | Data |
| --- | --- | --- | --- |
| Node Exporter Full | vendored 1860 | both | CPU, mem, disk, network, uptime (template var `nodename`) |
| SMARTctl | vendored 22604 | both | per-disk health/temperature/wear |
| NGINX exporter | vendored 12708 | yirukou | connections, requests, status codes |
| systemd-units | custom Nix | both | unit states, failed/degraded, restarts |
| services-overview | custom Nix | both | per-service state grid (see note) |
| fail2ban | custom Nix | yifuwuqi | banned IPs per jail, ban rate |
| prometheus | custom Nix | central | scrape health, TSDB, samples |
| loki | custom Nix | central | request/ingestion rates |
| grafana | custom Nix | central | Grafana self-metrics |
| postgres | custom Nix | central | pg_stat_* via postgres_exporter |

## Implementation steps

1. Download vendor JSONs (grafana.com download endpoints:
   `https://grafana.com/api/dashboards/<id>/revisions/<rev>/download`) into
   `vendor/`. Do **not** strip `id` in the committed files — strip at build
   time so vendored copies stay byte-identical to upstream.
2. Create `dashboards/lib.nix` — panel/dashboard helpers.
3. Create the custom boards (7 Nix files) under `dashboards/`.
4. Edit `modules/services/monitoring/grafana.nix`: assemble directory
   (`runCommand` + `jq del(.id)` + `writeText` JSONs), add
   `provision.dashboards.settings.providers`.
5. Edit `modules/services/monitoring/prometheus.nix`: `relabel_configs`
   (`host` → `instance`) in `mkScrapeConfig`; add Loki + Grafana self-metrics
   scrape jobs targeting the LAN address.
6. Add postgres exporter: `addresses.nix` metadata entry + pg_hba
   `127.0.0.1/32` line in `modules/services/postgresql.nix`.
7. Validate: `nix flake check`, `nixos-rebuild dry-build` for `yifuwuqi` and
   `yirukou` (addresses.nix is shared). Grafana's file provider validates JSON
   on load; Prometheus `checkConfig` is enabled.
8. Update docs: `docs/src/services/monitoring.md` (status table, topology,
   source files) and mark this plan implemented.

## Notes / trade-offs

- Provisioned dashboards are read-only in the UI; tweaks must be made in Nix.
- Vendored JSONs are static copies — updating them is a manual fetch of a new
  revision (grafana.com's download API is revision-number based and brittle).
- Custom panel queries must be verified against live exporter metric names
  after deploy; exact queries may need a tweak.
- `services-overview` cannot show per-unit CPU/memory: node_exporter's systemd
  collector only exposes unit state. Board is state/restart based; per-service
  CPU/mem requires a new exporter (out of scope, follow-up).
- App services (forgejo, nextcloud, arr stack, …) still have no exporters;
  only postgres is added here. Everything else is a follow-up.
- Grafana's `log.level` is currently `debug` — out of scope, left alone.
