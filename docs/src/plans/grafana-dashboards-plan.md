# Declarative Grafana Dashboards Plan

## Goal

Provision Grafana dashboards fully declaratively (Nix attrsets → JSON →
`services.grafana.provision.dashboards`) for all monitored services, matching
the existing style in `modules/services/monitoring/`.

## Design

Grafana is already provisioned (`modules/services/monitoring/grafana.nix`) with
datasources via `provision.datasources`. We extend the same mechanism:

- A new directory `modules/services/monitoring/dashboards/` holding one `.nix`
  file per dashboard, each returning a Grafana dashboard attrset (plain Nix,
  rendered with `builtins.toJSON` — no grafonnet/jsonnet dependency).
- A small shared helper `modules/services/monitoring/dashboards/lib.nix` with
  minimal panel builders (`mkTimeseries`, `mkStat`, `mkGauge`, `mkTarget`,
  grid positioning) so boards stay compact and consistent. Keep it stupidly
  simple — plain attrsets, no abstraction beyond what panels need.
- In `grafana.nix`, collect the dashboard files into a store directory
  (`pkgs.linkFarm` over `pkgs.writeText` JSON files) and add:

  ```nix
  provision.dashboards.settings.providers = [
    {
      name = "declarative";
      options.path = <farm path>;
      foldersFromFilesStructure = false;
    }
  ];
  ```

  Dashboards get stable `uid`s so they survive restarts and are editable-proof
  (provisioned boards are read-only in the UI — that is desired).

## Dashboards to add

1. **Host / exporter metrics** (`node`, `systemd`, `smartctl` on yifuwuqi +
   yirukou):
   - `host-overview` — CPU, memory, disk, network per `host` label
     (templated `host` variable from `label_values(node_uname_info, host)`).
   - `systemd-units` — unit states, failed units, service restarts.
   - `disks-smart` — SMART temperature, health, wear, disk I/O.
2. **Proxy & edge** (yirukou):
   - `nginx-proxy` — requests/s, status codes, connections
     (`nginx_http_requests_total` etc.).
   - `fail2ban` — banned IPs per jail, ban rate.
3. **Monitoring stack itself**:
   - `prometheus` — scrape durations, samples ingested, TSDB stats,
     target up/down.
   - `loki` — ingested lines/bytes, request rates (Loki exposes `/metrics`;
     add a scrape job — see below).
   - `grafana` — basic Grafana self-metrics (Grafana exposes `/metrics` on its
     own port; scrape locally).
4. **App services**:
   - Most app services (forgejo, nextcloud, postgres, …) currently have **no
     exporters**, so full boards are not possible yet. This plan covers:
     - a `services-overview` board built from the systemd exporter — per-unit
       CPU/memory of the main app services, giving useful coverage with zero
       new exporters.
     - enabling the `postgres` Prometheus exporter on yifuwuqi (postgres is
       already running for Grafana/Nextcloud) plus a `postgres` board — one
       small, well-supported exporter addition. This is the only new exporter
       in scope; anything further (forgejo metrics, nextcloud) is a follow-up.

## Implementation steps

1. Create `modules/services/monitoring/dashboards/lib.nix` — panel/dashboard
   helpers.
2. Create dashboard files under `modules/services/monitoring/dashboards/`:
   `host-overview.nix`, `systemd-units.nix`, `disks-smart.nix`,
   `nginx-proxy.nix`, `fail2ban.nix`, `prometheus.nix`, `loki.nix`,
   `grafana.nix`, `services-overview.nix`, `postgres.nix`.
3. Edit `modules/services/monitoring/grafana.nix`:
   - import the dashboards directory, render to JSON, build a `linkFarm`;
   - add `provision.dashboards.settings.providers` pointing at it.
4. Edit `modules/services/monitoring/prometheus.nix` — add scrape jobs for
   Loki (`127.0.0.1:<loki port>/metrics`) and Grafana
   (`127.0.0.1:<grafana port>/metrics`) on the central host. (Prometheus
   already scrapes itself.)
5. Add postgres exporter:
   - `modules/addresses.nix`: add a `postgres` entry under
     `monitoring.exporters` if it fits the existing metadata pattern, with
     `settings` for the postgres data source (socket, user); verify
     `exporters.nix` `serviceAvailable` handles it (default `true` branch
     likely suffices).
6. Validate:
   - `nix flake check` / `nixos-rebuild dry-build` for `yifuwuqi` (and
     `yirukou` since `addresses.nix` is shared).
   - Confirm Prometheus `checkConfig` still passes (it's enabled).
7. Update docs: `docs/src/services/monitoring.md` (status table, topology,
   source files list) to mention declarative dashboards and the new scrape
   jobs / postgres exporter.

## Notes / trade-offs

- Provisioned dashboards are read-only in the UI; tweaks must be made in Nix.
  That's the point, but worth knowing.
- Panels are hand-built from the exported metric names — verify metric names
  against the node/systemd/smartctl/nginx/fail2ban exporter docs during
  implementation; exact queries may need a live check after deploy.
- Grafana's `log.level` is currently `debug` — out of scope, left alone.
