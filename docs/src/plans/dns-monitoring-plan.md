# DNS Monitoring in Grafana Plan (AdGuard Home + Unbound)

## Goal

Get DNS metrics into Grafana on the `yifuwuqi` central monitoring stack for
both hosts (`yifuwuqi`, `yirukou`):

- **AdGuard Home** query/block statistics (currently only visible as rolling
  24h aggregates in the AGH web UI — no history).
- **Unbound** resolver stats (cache hit rate, recursion time, memory).

## Design

AdGuard Home ships **no native Prometheus endpoint** (long-standing upstream
feature request), so an exporter is required. Unbound needs `unbound_exporter`
talk to its control socket. Both exporters run **per-host** and plug into the
existing `monitoring.exporters` framework in `modules/addresses.nix`, which
already generates the systemd unit (`exporters.nix`) and the scrape job with
`instance = <host>` labels (`prometheus.nix`). No firewall changes: both
exporters talk to local sockets/loopback only.

### Exporter choice: `znand-dev/adguardexporter`

Researched alternatives and why they lost:

| Exporter | Verdict |
| --- | --- |
| `znand-dev/adguardexporter` (Go, single `main.go`) | **Chosen** — richest metrics (query reasons, types, upstream latency histograms, per-client), actively maintained (Aug 2026 commits), per-host model fits the framework |
| `henrywhitaker3/adguard-exporter` | Multi-instance single exporter, established dashboard 20799, but stale (Sep 2025) and fewer metrics |
| `JonanekDev/AdGuardHome-Exporter` (dashboard 24520) | Node/TS, 13 commits, no releases, port 9100 conflicts with node_exporter — rejected |
| `prometheus-json-exporter` (in nixpkgs) | Works for aggregate counters, but AGH top-* lists are JSON maps that json_exporter cannot label → loses the interesting stats; no login support |
| textfile collector script | DIY counter/reset handling, more maintenance |

Multi-instance support is not needed: the per-host framework labels series with
`instance=host`, which is exactly how dashboard 23579 separates instances.

### Auth note

The AGH HTTP API on `:3333` is currently **unauthenticated** (no `users`
configured in `services.adguardhome.settings`). Per decision, auth stays off
(AGH is only reachable over Tailscale/VPN). The exporter sends Basic auth
headers on every request (verified in source: `SetBasicAuth`); AGH ignores
them while open, so dummy credentials work.

## Files

### New

- `packages/adguard-exporter/default.nix`
  - `buildGoModule`, `pname = "adguard-exporter"`, pinned master commit of
    `znandev/adguardexporter` (~2026-08-10; the optional-GeoIP feature needed
    is post-v1.2.3). Follow the `packages/tpm-fido2/default.nix` pattern;
    fill `hash` + `vendorHash` from first build error.
- `modules/services/monitoring/adguard-exporter.nix`
  - Defines `services.prometheus.exporters.adguard` options (mirroring the
    nixpkgs exporter module shape so `exporters.nix` `mkExporter` works):
    `enable`, `port = 9617`, `listenAddress`, `openFirewall`, plus
    `scrapeInterval = "15s"` and dummy `adguardUser`/`adguardPass`.
  - AGH URL computed per-host, no config needed:
    `http://127.0.0.1:${toString allAddresses.hosts.<host>.services.adguardhome.port}`.
  - `systemd.services.prometheus-adguard-exporter` (DynamicUser,
    `after = ["adguardhome.service"]`) with env
    `ADGUARD_HOST/ADGUARD_USER/ADGUARD_PASS/EXPORTER_PORT/SCRAPE_INTERVAL`.
  - Referenced via `pkgs.callPackage ../../packages/adguard-exporter { }`
    (same as tpm-fido2 — no overlay needed).
- `modules/services/monitoring/dashboards/vendor/adguard.json`
  - grafana.com dashboard **23579** "AdGuard Metrics Statistics" (rev
    `https://grafana.com/api/dashboards/23579/revisions/latest/download`).
  - No `DS_PROMETHEUS` variable — the existing jq pipeline is a no-op for it.
  - No `$instance` variable; with 2 hosts panels show one series per instance.
- `modules/services/monitoring/dashboards/vendor/unbound.json`
  - grafana.com dashboard **21006** "Unbound" (rev
    `https://grafana.com/api/dashboards/21006/revisions/latest/download`).
  - Uses `DS_PROMETHEUS` (handled by the vendor jq pipeline) and an
    `$instance` variable querying `label_values(unbound_up, instance)` — fed by
    the framework's `instance=host` relabel.

### Modified

- `modules/addresses.nix` — add to `monitoring.exporters`:
  ```nix
  adguard = {
    hosts = "scrapeHosts";
  };
  unbound = {
    hosts = "scrapeHosts";
    settings.unbound = {
      host = "unix:///run/unbound/unbound.ctl";
      ca = null;
      certificate = null;
      key = null;
    };
  };
  ```
- `modules/services/unbound.nix` — add `extended-statistics = "yes"` to
  `server` settings (required for `unbound_recursion_time_seconds_avg/median`
  panels on dashboard 21006).
- `hosts/yifuwuqi/services.nix`, `hosts/yirukou/services.nix` — import
  `../../modules/services/monitoring/adguard-exporter.nix` (both hosts run AGH
  + Unbound).

The nixpkgs `services.prometheus.exporters.unbound` module needs no custom
module: it runs as `User = unbound` (matching the repo's unbound service),
`after/requires unbound.service`, and connects over the control socket the
`localControlSocketPath` option already creates at `/run/unbound/unbound.ctl`
(verified live: socket exists, owned by unbound).

## Implementation steps

1. Add `packages/adguard-exporter/default.nix`; iterate `nix build` to capture
   `hash`/`vendorHash` (fakeHash → "got" from error).
2. Add `modules/services/monitoring/adguard-exporter.nix`.
3. Register `adguard` + `unbound` in `monitoring.exporters` (addresses.nix).
4. Add `extended-statistics = "yes"` to `modules/services/unbound.nix`.
5. Download dashboard JSONs into `vendor/` (keep byte-identical to upstream;
   `id` stripping happens at build time).
6. Import the new module in both hosts' `services.nix`.
7. Validate: `nix flake check`, `nixos-rebuild dry-build` for `yifuwuqi` and
   `yirukou` (addresses.nix is shared); Prometheus `checkConfig` is enabled.
8. Deploy both hosts; verify:
   - `curl localhost:9617/metrics` (`adguard_*` series, both hosts)
   - `curl localhost:9167/metrics` (`unbound_*` series, both hosts)
   - Dashboards 23579 + 21006 load in Grafana and show `instance=yifuwuqi` /
     `instance=yirukou`.
9. Update docs (`docs/src/services/monitoring.md`) and mark this plan
   implemented.

## Notes / trade-offs

- Dashboard 23579's GeoIP/ISP/geomap panels will be **empty**: geo metrics
  require a MaxMind GeoLite2-City.mmdb (license + download step). Exporter
  skips geo metrics without the DB (feature added Mar 2026); panels can be
  trimmed later via jq if annoying.
- AGH auth stays **off** (VPN-only exposure, per decision). If a user/password
  is ever added, AGH supports HTTP Basic auth, so the exporter keeps working —
  only swap the dummy creds for sops-backed ones.
- The AGH `top_*` metrics are cumulative per AGH stats-window; dashboards
  apply `rate()`/`increase()` — nothing to do on the exporter side.
- Vendored dashboard JSONs are static copies; updating = manual re-fetch of a
  new grafana.com revision (same caveat as existing vendored boards).
- `unbound` exporter emits metrics from `unbound-control stats`; cache
  hit-rate panels use `unbound_cache_hit_ratio` etc. — verify against the live
  ​exporter after deploy, tweak queries if the nixpkgs version (0.6.0) differs.
