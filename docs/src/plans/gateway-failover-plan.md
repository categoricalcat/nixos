# Gateway Failover: Level-Triggered Rewrite

## Status: ACTIVE — Phases 1–7 implemented 2026-11-12, statically checked (formatters, shellcheck, evaluation of both hosts) and example-tested (VM scenarios); yifuwuqi deployed and drilled 2026-11-13, yirukou not deployed

## Objective

- Converge the default route to the primary uplink while it is debounced-healthy and to the fallback otherwise, from any route-table state and any event order. No manual replug.
- One owner per route. Retire the single-node VRRP setup.

## Current state

Journal evidence from `yifuwuqi` and `yirukou`, 2026-11-08 to 2026-11-12:

- **Soft failover is a no-op.** `FAULT` adds the fallback default (metric 200) but never removes the primary (metric 100), so the kernel keeps using the dead primary until carrier loss flushes it. `yifuwuqi` 2026-11-12 16:07:29 to 16:12:45.
- **Routes exist only on VRRP edges.** The kernel drops them with the address and nothing reinstalls them. `yifuwuqi` had no default route on 2026-11-12 from 16:12:46 to 17:27:12 while the fallback re-leased five times.
- **Boot with the primary dead installs no default.** `yirukou` 2026-11-08 16:32 to 16:47, with the fallback leased from 16:32:56.
- **The check overruns its interval.** Two targets at `-W 1` fill `interval 2`, so every other run is skipped and `fall 4` takes 12 s.
- `ManageForeignRoutes=false` is set only on `yifuwuqi`; `virtualRouterId`, `priority`, `unicastPeers` and `pingTargets` are duplicated across both hosts in `modules/addresses.nix`.

## Decisions

1. **Engine**: one `wan-monitor.service` loop replaces `services.keepalived` and `keepalived-boot-delay.timer`.
1. **Ownership**:
   - Fallback default: networkd (`UseGateway=true`, `RouteMetric` 200), so the lease owner restores it on every lease or carrier event.
   - Primary default (metric 100): `wan-monitor`. Present only while the primary is up, re-asserted every tick.
1. **Kept**: probes through /32 routes pinned to the primary, `rise 2`, `fall 4`, 2 s tick, `conntrack -F` on effective change, metric names.
1. **No address or lease on the primary** means down immediately (the kernel has already dropped the route); ping loss means down after `fall`.
1. **Start state is read from the kernel**, so a restart neither moves traffic nor flushes conntrack. Stop leaves routes untouched.
1. **Lease router** comes from DHCP option 3 only (`networkctl dhcp-lease IF 3`). `src` comes from the interface address, so the `source` attribute goes away.
1. **Metric label** becomes `interface` (the primary) only; the module no longer knows the fallback gateway. The dashboard aggregates `max by (host)` and is unaffected.
1. **`ManageForeignRoutes=false`** moves into the module, since both hosts install foreign routes.

## Phases

### Phase 1 — Persist the plan

This file.

### Phase 2 — Module

`packages/gateway-failover/default.nix`: delete `wan-check`, `wan-notify`, the lease and route helpers and the keepalived config. Add `wan-monitor` (`writeShellApplication`) and its unit (`Restart=always`, after `network.target`), logging one journal line per transition. Set `systemd.network.config.networkConfig.ManageForeignRoutes = false`.

### Phase 3 — networkd owns the fallback default

- `hosts/yifuwuqi/networking/interfaces/enp4s0.nix`: `UseGateway = true` and `RouteMetric` from `addresses.network.secondary.routeMetric`.
- `hosts/yirukou/networking/wans.nix`: fallback `UseGateway = true`.
- `hosts/yifuwuqi/networking/interfaces/eno1.nix`: drop `ManageForeignRoutes` (moved) and fix the comments.

### Phase 4 — Address registry

`modules/addresses.nix`, both hosts: `gatewayFailover` shrinks to `primary = { interface; gateway; metric; }` plus `pingTargets`. Delete `fallback`, `source`, `virtualRouterId`, `priority` and `unicastPeers`; hoist the identical `pingTargets` list into one binding; add `network.secondary.routeMetric = 200` on `yifuwuqi`.

### Phase 5 — VM test

`packages/gateway-failover/test.nix`, wired into the flake `checks` through `pkgs.testers.runNixOSTest`. Nodes: `isp1` and `isp2` (networkd DHCP servers that both own the probe targets), `dhcpEdge` (the uplink units of `yirukou`) and `staticEdge` (those of `yifuwuqi`). Asserted on both edges:

1. Healthy boot: egress through the primary.
1. Soft failure (`isp1` stops answering): egress through the fallback, primary default gone.
1. Primary default put back by hand during the failure: gone within one tick.
1. Fallback carrier flap during the failure: the fallback default returns.
1. Reboot with the primary dead: egress through the fallback.
1. Heal: egress through the primary.
1. Manual deletion of the primary default: back within one tick.
1. Primary carrier flap: fallback while down, primary afterwards.
1. `systemctl restart wan-monitor`: route and transition timestamp unchanged.

### Phase 6 — Docs

`docs/src/networking/yirukou.md` section 4, `docs/src/hosts/yirukou.md` section 3.1, `docs/src/hosts/yifuwuqi.md` (the `enp4s0` row and the foreign-route bullet), `docs/src/services/monitoring.md` and `docs/src/README.md`.

### Phase 7 — Verify

Format the changed files, evaluate both hosts, build the VM test, audit `git diff`. Evidence reached: shellcheck and evaluation (static) plus the VM scenarios (example-tested). Not covered: real NIC carrier behaviour, CPE DHCP timing and the conntrack effect on live NAT flows, which need the drill below.

## Rollout order

- [x] **1** `deploy .#yifuwuqi` (User), then read-only checks (AI): `systemctl status wan-monitor`; `ip -4 route show default` lists metric 100 via `10.42.0.1` and a `proto dhcp` metric 200 route. Verified 2026-11-13 05:37–05:38: `wan-monitor` active; keepalived stopped/not-found; `ManageForeignRoutes=false`; enp4s0 `UseGateway=true`/`RouteMetric=200`; primary default + both probe /32s pinned; journal `eno1 active`; leftover static metric-200 default present (harmless per plan).
- [x] **2** Drill on `yifuwuqi` (User): pull `eno1` for more than 10 s (journal reports the primary inactive, traffic leaves through the fallback), replug (active again within about 5 s), then `ip route del default dev eno1 metric 100` (restored within 3 s). Verified 2026-11-13: unplug 05:39:18 `eno1 inactive: no address or gateway`, metric 100 and probe /32s gone, egress via metric 200 (`200.160.0.8` TTL 56); replug 05:42:02 `eno1 active`, metric 100 and pins back, TTL 57; after `ip route del` the metric 100 default was present again with no new journal line and the transition timestamp still 05:42:02 (re-assert, not a transition). The 3 s bound was not stopwatched.
- [ ] **3** `deploy .#yirukou` (User), then read-only checks over `ai-ssh` (AI). Expect a WAN blip of about 5 s while networkd restarts and re-leases both WANs, and one last conntrack flush from the old keepalived `STOP` notify.
- [ ] **4** Retire this plan once both hosts pass (AI).

The static fallback default left by the old notify script lingers until a reboot or lease loss; it duplicates the networkd route and is harmless. Rollback is the deploy-rs magic rollback (30 s) or the previous generation.

## Open questions

1. Physical: `eno1` to `yirukou` `enp3s0` lost carrier 34 times since 2026-11-11, always at 1 Gbps, and not once in about 28 h while downshifted to 100 Mbps. Swap the cable and check `ethtool --show-eee eno1`; no config change fixes it.
1. The pinned /32 for `200.160.0.8` also captures the `ntpbr` blackbox and smokeping peer, so that rung reads down during a failover. Keep it, or move the probes to fwmark policy routing later?
1. `wan-monitor` runs as root and unsandboxed, as keepalived did. Adopt `systemdHardening` with `CAP_NET_ADMIN`, `CAP_NET_RAW` and `AF_NETLINK` exceptions later?
