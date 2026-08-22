# DNS Privacy Hardening Plan (third-party handoff delta)

## Status: PLANNED — not applied. Do not deploy from this document.

Origin: an external "Automated Deployment Handoff: NixOS Privacy-Hardened DNS &
Observability" written without knowledge of this flake. This document is the
fact-checked delta: what the handoff got wrong, and the settings-only subset
worth applying.

## Objective

Tighten DNS privacy on both resolver hosts without touching the deployed
architecture. The handoff's `dns-stack.nix` must **not** be merged: it assumes a
single greenfield host and would break ports, the dual-host scrape framework,
the valkey L2 cache, the unix control socket, the nginx/sops Grafana, the
`resolved` stub arrangement, and the AGH rewrites/TLS/filters.

## Scope: both hosts, shared modules

`yirukou` is the primary resolver, `yifuwuqi` the secondary. Both import the
same two modules, so **every edit lands on both hosts at once**:

- `modules/services/adguardhome.nix` — imported by `hosts/yirukou/services.nix`
  and `hosts/yifuwuqi/services.nix`
- `modules/services/unbound.nix` — same two hosts

No per-host branching is planned. Existing per-host differences
(`dnsBindHosts`, `dns.threads`, valkey locality) stay untouched.

```text
LAN clients (DHCP: 10.42.0.1 primary, 10.42.0.2 secondary)
  -> AGH :53 (per host)
     -> unbound 127.0.0.1:5335 (per host)
        -> valkey L2 (on yifuwuqi, shared)
        -> root / TLD / authoritative
Prometheus (yifuwuqi) -> adguard exporter :9617 + unbound exporter :9167 (both hosts)
```

## Fact-check of the handoff

| Handoff claim | Reality in this repo |
| --- | --- |
| Native NixOS, no Docker | Correct, already so on both hosts |
| AGH on 53, unbound `127.0.0.1:5335`, upstream `127.0.0.1:5335` | Correct, already so |
| AGH admin UI on 3000 | Wrong: **3333** (`sharedServices.adguardhome.port` in `modules/addresses.nix`) |
| Grafana on 3001, `http_addr = 0.0.0.0` | Wrong: **3030**, LAN-bound, behind nginx at `grafana.fufu.land`, sops secret key, postgres backend, only on yifuwuqi |
| `services.resolved.enable = false` | Wrong and harmful: both hosts run resolved with `DNSStubListener = "no"`, which already frees port 53 and keeps `/etc/resolv.conf` sane |
| unbound TCP remote-control on 8953 | Wrong: `localControlSocketPath = /run/unbound/unbound.ctl`; the nixpkgs exporter's `controlInterface` option was **removed** upstream, we use `unbound.host = "unix:///run/unbound/unbound.ctl"` |
| Prometheus scrapes AGH `/metrics` with basic_auth | Wrong: AGH has no native `/metrics`. Custom exporter on **9617** (`modules/services/monitoring/adguard-exporter`); AGH auth is off (VPN-only), creds are dummies |
| Two static scrape jobs | Wrong shape: jobs are generated from `monitoring.exporters` for both `scrapeHosts` with `instance=<host>` labels |
| Dashboards 21006 + 13330 | Half right: 21006 (unbound) is vendored; the AGH board is **23579 rev 3**, not 13330 |
| `msg-cache-size 50m` / `rrset-cache-size 100m` | Reject: live values are **300m/600m** with valkey L2 and a tuned 1h-7d TTL window (`docs/src/plans/dns-cache-timing-plan.md`) |
| `extended-statistics`, `prefetch`, `prefetch-key`, `serve-expired`, `qname-minimisation`, `hide-identity`, `hide-version`, `harden-glue`, `harden-dnssec-stripped` | Already set |
| Zero query logs | Not today: `querylog.enabled/file_enabled = true`, `interval = "720h"` |
| safebrowsing/parental/safesearch off | Currently unset (AGH defaults apply); worth pinning explicitly |
| ECS disabled | Opposite today: `edns_client_subnet.enabled = true`, `use_custom = false` |
| `private-address`, `harden-below-nxdomain`, explicit log flags | Genuinely missing — the useful part of the handoff |
| `use-caps-for-id` | Reject: 0x20 encoding breaks some authoritative servers, no real gain behind DNSSEC validation |

## Decisions

- **No `anonymize_client_ip`** on either host. It masks the last octet in logs
  *and* stats, collapsing `adguard_query_client_reason_total` (two panels in
  `vendor/adguard.json`) into a single bucket on yirukou, where all LAN clients
  live.
- **Query log stays enabled** but becomes RAM-only. The AdGuard exporter derives
  `adguard_query_*` from the query-log API, so the handoff's outright disable
  would blank those panels.
- **Retention is `size_memory`, not `interval`.** Verified in AGH source
  (`internal/querylog/qlog.go`, `querylog.go`): the memory buffer is
  `container.RingBuffer[*logEntry]` sized by `MemSize` **entries**, and with
  `FileEnabled = false` nothing is ever flushed — the oldest entry is dropped on
  push. `interval` (`RotationIvl`) is only the *file* rotation interval. The
  current `size_memory = 10485760` with its `# 10MiB` comment is a misread: it
  is 10.4M entries, which becomes a large RAM ring once file writes are off
  (AGH runs with `GOMEMLIMIT = 2560MiB`).

## Change 1 — `modules/services/adguardhome.nix` (both hosts)

`settings.dns`:

- Add `safebrowsing_enabled = false;`, `parental_enabled = false;`,
  `safesearch_enabled = false;` — pins the "no Big Tech callback" posture
  explicitly instead of relying on AGH defaults.
- `edns_client_subnet`: from `{ enabled = true; use_custom = false; }` to
  `{ enabled = true; use_custom = true; custom_ip = "200.20.186.76"; }` so
  client subnets never leave the host, even on the AGH -> unbound hop.
  Address is NTP.br `d.st1.ntp.br` at Observatório Nacional (unicast, Rio).
  AGH masks ECS to /24, so authorities would see `200.20.186.0/24`.
- Untouched: `bind_hosts`, `upstream_dns`, `upstream_mode`, `bootstrap_dns`,
  `local_ptr_upstreams`, `ratelimit`, every `cache_*` key, `enable_dnssec`,
  `serve_http3`, `upstream_timeout`.

`settings.querylog`:

- `enabled = true` (unchanged — feeds the exporter)
- `file_enabled = true` -> **`false`** (no query log on disk on either host)
- `interval = "720h"` -> **`"24h"`** (only affects file rotation; documents
  intent and applies if file logging is ever re-enabled)
- `size_memory = 10485760` -> **`50000`** entries, commented as the real
  retention knob. At the observed ~9-10k queries/day/host that is several days
  of history for the exporter and the AGH UI, at tens of MB.

`settings.statistics` (aggregates only, no per-query data), `settings.log`,
`filtering`, `filters`, `user_rules`, `tls`, `http`: unchanged.

## Change 2 — `modules/services/unbound.nix` (both hosts)

Add to `settings.server` only:

- `verbosity = 0;`
- `log-queries = "no";`, `log-replies = "no";`, `log-servfail = "yes";`
- `harden-below-nxdomain = "yes";`
- `private-address`: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`,
  `169.254.0.0/16`, `fd00::/8`, `fe80::/10`

Rebinding-protection safety, verified rather than assumed:

- `fufu.land` has **no public A records** (checked against 1.1.1.1: apex,
  `grafana.`, `dns.`, and a random label all empty), so stripping RFC1918
  answers from public zones cannot break internal names. The `*.fufu.land` ->
  `10.42.0.1` mapping is an AGH rewrite that never reaches unbound.
- **Do not** add `100.64.0.0/10`: that is Tailscale/CGNAT space.
- `private-address` filters address records; PTR for `10.42.x` via
  `local_ptr_upstreams` is unaffected.

Explicitly not touched: `module-config` (validator cachedb iterator), cache
sizes, TTL window, `serve-expired*`, threads, `so-*`, `fast-server-*`,
`edns-buffer-size`, `do-ip6`, the cachedb/valkey block,
`localControlSocketPath`.

## Not touched at all

`modules/services/monitoring/prometheus.nix`,
`modules/services/monitoring/grafana.nix`,
`modules/services/monitoring/exporters.nix`, the AdGuard exporter
module/package, vendored dashboards, `services.resolved` on either host,
firewalls, `modules/addresses.nix`.

## ECS and the RJ prefix

AGH's ECS option currently only tags the **AGH -> unbound** hop. unbound's
`module-config` is `"validator cachedb iterator"` — no `subnetcache`, no
`send-client-subnet` — so no client subnet is forwarded to authoritative
servers. CDNs already geo-steer on each host's WAN egress IP.

So a Rio `custom_ip` is a **privacy** change (unbound stops seeing
LAN/Tailscale client subnets), **not** geo-steering. Real RJ steering would
need unbound's `subnetcache` module plus `send-client-subnet` for selected
authorities, fragmenting the shared valkey key space across both instances —
out of scope, and pointless if both WAN egresses are already in RJ.

Chosen `custom_ip`: **`200.20.186.76`** (`d.st1.ntp.br`). Reasons it is a
reliable static pick:

- Unicast (not RNP EduDNS / Cloudflare-style anycast, which GeoIP often
  mis-places).
- Documented for years as NTP.br stratum-1 at Observatório Nacional, Rio
  (NTP.org PublicTimeServer000643; ntp.br server list).
- IPinfo: city Rio de Janeiro, AS2715 (FAPERJ / Rede Rio), org Observatório
  Nacional, prefix `200.20.0.0/16`.
- Same NIC.br NTP program as `a.ntp.br` (`200.160.0.8`), which is São Paulo
  and is **not** used here.

Rejected alternatives: NIC.br `200.160.0.8` (SP), RNP EduDNS `200.19.16.53`
(anycast), UFRJ DHCP-looking hosts in `146.164.0.0/16`.

## Rollout

Build first, then deploy the secondary before the primary so LAN resolution
never depends on the host being restarted (DHCP hands out `10.42.0.1` =
yirukou and `10.42.0.2` = yifuwuqi; yifuwuqi's own `systemNameservers` are
`10.42.0.1` then `127.0.0.1`).

1. `nix flake check`, then `nixos-rebuild dry-build --flake .#yifuwuqi` and
   `--flake .#yirukou` (both hosts consume the same two modules).
2. Deploy **yifuwuqi** (secondary): `sudo nixos-rebuild switch --flake .#yifuwuqi`.
   Must be `switch`, not `boot`: unbound only picks up the new conf through
   `restartTriggers` on switch — a `boot`-style deploy previously left yirukou
   on a stale config for a day (`docs/src/plans/dns-monitoring-plan.md`,
   Phase 2).
3. Verify on yifuwuqi, then deploy **yirukou** (primary):
   `sudo nixos-rebuild switch --flake .#yirukou`.
4. Verify on yirukou. Brief AGH restart blips fail over to the other server in
   the DHCP-provided pair.

## Verification per host

- `systemctl status unbound adguardhome` — both active on the new generation.
- `unbound-control -c /etc/unbound/unbound.conf status` and
  `dig @127.0.0.1 -p 5335 example.com` — resolution still works after
  `private-address`.
- `dig @127.0.0.1 grafana.fufu.land` still returns `10.42.0.1` (rewrite path
  unaffected).
- No query log file growth in the AGH data dir (`querylog.json*`).
- `curl -s 127.0.0.1:9617/metrics | grep -c adguard_query_` — non-zero on both
  hosts (RAM-only log still feeds the exporter).
- `curl -s 127.0.0.1:9167/metrics | grep -c unbound_` — ~54 series (extended
  stats intact).
- Grafana AGH + unbound dashboards populate for `host=yirukou` and
  `host=yifuwuqi`.

## Docs follow-up

Append to `docs/src/services/monitoring.md`: the query log is RAM-only with
`size_memory` as the retention knob, and `anonymize_client_ip` stays off to
preserve the per-client panels.
