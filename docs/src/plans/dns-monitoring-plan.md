# DNS Monitoring in Grafana Plan (AdGuard Home + Unbound)

## Goal

Get DNS metrics into Grafana on the `yifuwuqi` central monitoring stack for
both hosts (`yifuwuqi`, `yirukou`):

- **AdGuard Home** query/block statistics (currently only visible as rolling
  24h aggregates in the AGH web UI — no history).
- **Unbound** resolver stats (cache hit rate, recursion time, memory).

## Status: IMPLEMENTED

Deployed 2026-08-13 on both hosts. See "Implementation notes" below for
corrections made during execution.

## Design

AdGuard Home ships **no native Prometheus endpoint** (long-standing upstream
feature request), so an exporter is required. Unbound needs `unbound_exporter`
talk to its control socket. Both exporters run **per-host** and plug into the
existing `monitoring.exporters` framework in `modules/addresses.nix`, which
already generates the systemd unit (`exporters.nix`) and the scrape job with
`instance = <host>` labels (`prometheus.nix`). No new firewall changes: both
exporters follow the framework's existing LAN-interface port opening for
scrape hosts.

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
them while open, so dummy credentials work (verified live: 200 with
`-u admin:dummy`).

## Files

### New

- `modules/services/monitoring/adguard-exporter/package.nix`
  - `buildGoModule`, `pname = "adguard-exporter"`, pinned master commit
    `9dba360e6cced90da8de839e206518dfa37a91af` of `znand-dev/adguardexporter`
    (2026-08-10; the optional-GeoIP feature needed is post-v1.2.3). Follows the
    `packages/tpm-fido2/default.nix` pattern; hash captured from build errors.
    Binary name is `adguardexporter`.
  - nixpkgs Go 1.26.5 satisfies `go.mod` (`go 1.25.0` / `toolchain go1.26.5`),
    so no toolchain download happens in the sandbox.
- `modules/services/monitoring/adguard-exporter/default.nix`
  - Declares `services.prometheus.exporters.adguard` options (mirroring the
    nixpkgs exporter module shape so `exporters.nix` `mkExporter` works):
    `enable`, `port = 9617`, `listenAddress`, `openFirewall`, plus
    `scrapeInterval = "15"` (integer **seconds** — the binary parses it with
    `strconv.Atoi`; the `"15s"` form in the upstream README silently falls
    back to the 15s default) and dummy `adguardUser`/`adguardPass`.
  - AGH URL computed per-host, no config needed:
    `http://127.0.0.1:${toString allAddresses.hosts.<host>.services.adguardhome.port}`.
    The package lives next to the module, referenced via
    `pkgs.callPackage ./package.nix { }`.
  - `systemd.services.prometheus-adguard-exporter` (DynamicUser, nixpkgs-style
    hardening, `after`/`wants = ["adguardhome.service"]`) with env
    `ADGUARD_HOST/ADGUARD_USER/ADGUARD_PASS/EXPORTER_PORT/SCRAPE_INTERVAL/LOG_LEVEL`.
  - `listenAddress` is declared for framework compatibility only — the binary
    hardcodes `":"+port` (binds all interfaces, same as the other exporters on
    these hosts).
- `modules/services/monitoring/dashboards/vendor/adguard.json`
  - grafana.com dashboard **23579** "AdGuard Metrics Statistics", **revision 3**
    (`https://grafana.com/api/dashboards/23579/revisions/3/download`).
  - **Not `revisions/latest`**: the latest revision (4) uses the new v2beta1
    dashboard schema (`DashboardWithAccessInfo`), which Grafana file-based
    provisioning does not accept (grafana/grafana#123607). Revision 3
    (2026-03-09, classic schema v42) is the final classic revision and
    contains panels for every metric the current exporter emits (upstream
    latency histograms, ISP, GeoIP, dedup).
  - No `DS_PROMETHEUS` variable — the existing jq pipeline is a no-op for it
    (panel datasources are `{type: prometheus, uid: "${DS_PROMETHEUS}"}`
    objects, which the pipeline rewrites).
  - No `$instance` variable; with 2 hosts panels show one series per instance.
- `modules/services/monitoring/dashboards/vendor/unbound.json`
  - grafana.com dashboard **21006** "Unbound" (rev
    `https://grafana.com/api/dashboards/21006/revisions/latest/download`).
  - Uses `DS_PROMETHEUS` (handled by the vendor jq pipeline) and an
    `$instance` variable querying `label_values(unbound_up, instance)` — fed by
    the framework's `instance=host` relabel.

### Modified

- `modules/addresses.nix` — added to `monitoring.exporters`:
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
- `modules/services/unbound.nix` — added `extended-statistics = "yes"` to
  `server` settings (required for `unbound_recursion_time_seconds_avg/median`
  panels on dashboard 21006).
- `hosts/yifuwuqi/services.nix`, `hosts/yirukou/services.nix` — import
  `../../modules/services/monitoring/adguard-exporter` (directory default.nix;
  both hosts run AGH + Unbound).

The nixpkgs `services.prometheus.exporters.unbound` module needs no custom
module: it runs as `User = unbound` (matching the repo's unbound service),
`after/requires unbound.service`, and connects over the control socket the
`localControlSocketPath` option already creates at `/run/unbound/unbound.ctl`
(verified live: socket exists, owned by `unbound:unbound` 660).

## Implementation steps

1. Add `modules/services/monitoring/adguard-exporter/package.nix`; capture
   `hash`/`vendorHash` from build errors (fakeHash → "got").
2. Add `modules/services/monitoring/adguard-exporter/default.nix`.
3. Register `adguard` + `unbound` in `monitoring.exporters` (addresses.nix).
4. Add `extended-statistics = "yes"` to `modules/services/unbound.nix`.
5. Download dashboard JSONs into `vendor/` (byte-identical to upstream; `id`
   stripping happens at build time).
6. Import the new module in both hosts' `services.nix`.
7. Validate: `nix flake check` (deadnix/nixf-diagnose/statix/treefmt — all
   Passed), dry-build `yifuwuqi` and `yirukou` (addresses.nix is shared);
   Prometheus `checkConfig` is enabled.
8. Deploy both hosts; verify:
   - `curl localhost:9617/metrics` (`adguard_*` series, both hosts)
   - `curl localhost:9167/metrics` (`unbound_*` series, both hosts)
   - Dashboards 23579 + 21006 load in Grafana and show `instance=yifuwuqi` /
     `instance=yirukou`.
9. Update docs (`docs/src/services/monitoring.md`) and mark this plan
   implemented.

## Implementation notes (2026-08-13)

- Hash capture used the flake's own nixpkgs via
  `nix build --impure --expr 'let flake = builtins.getFlake (toString ./.); pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux; in pkgs.callPackage ./modules/services/monitoring/adguard-exporter/package.nix { }'`
  so the go-module vendor hash matches the pinned Go version.
- Flake evaluation ignores untracked files: new files must be `git add -N`
  before `nix build`/`nix flake check` on a dirty tree.
- Smoke-tested the built binary against the live AGH API before deploying
  (metrics served, GeoIP disabled gracefully).
- The exporter's `adguard_dns_queries_total` etc. are gauges reflecting AGH's
  rolling 24h window; the dashboards' `rate()`/`increase()` still work (the
  gauge is monotonic within a window; the rollover looks like a counter reset
  that `rate()` handles). The `adguard_query_*` series are true deduped
  counters from the query log.
- Deployment ran with `sudo nixos-rebuild switch --flake .#<host>`
  (`--target-host root@yirukou` for the remote host) — root was required for
  the profile switch.

## Notes / trade-offs

- Dashboard 23579's GeoIP/ISP/geomap panels will be **empty**: geo metrics
  require a MaxMind GeoLite2-City.mmdb (license + download step). Exporter
  skips geo metrics without the DB (feature added Mar 2026); panels can be
  trimmed later via jq if annoying.
- Dashboard 23579 must stay on classic-schema **revision 3**; future
  revisions are v2beta1 format, which file provisioning cannot import.
  Re-fetching "latest" will silently produce an unprovisioned dashboard.
- AGH auth stays **off** (VPN-only exposure, per decision). If a user/password
  is ever added, AGH supports HTTP Basic auth, so the exporter keeps working —
  only swap the dummy creds for sops-backed ones (change the
  `adguardUser`/`adguardPass` options).
- The AGH `top_*` metrics are cumulative per AGH stats-window; dashboards
  apply `rate()`/`increase()` — nothing to do on the exporter side.
- Vendored dashboard JSONs are static copies; updating = manual re-fetch of a
  new grafana.com revision (same caveat as existing vendored boards).
- `unbound` exporter emits metrics from `unbound-control stats`; cache
  hit-rate panels use `unbound_cache_hit_ratio` etc. — verify against the live
  exporter after deploy, tweak queries if the nixpkgs version (0.6.0) differs.
