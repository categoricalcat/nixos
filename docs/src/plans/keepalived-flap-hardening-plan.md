# Keepalived Flap Hardening Plan

## Objective

Stop keepalived (yirukou and yifuwuqi) from flipping `FAULT → BACKUP → MASTER`
during transient upstream/peering packet loss, and stop each transition from
flushing conntrack for the whole LAN. Today every transition runs `conntrack -F`,
resetting every active connection — which *amplifies* real ~6-14% ISP downstream
loss into the perceived ~25% loss on all devices. Real WAN failover on sustained
outage must still work.

## Status: PLANNED — not applied. Fact-checked 2026-08-20

## Current State

### Evidence (2026-08-20, -03)

| Signal | Observation |
|--------|-------------|
| `speedtest-go` on yifuwuqi | download **25.70 Mbps**, upload **783.86 Mbps**, **1.33% loss** |
| MTR yirukou → 1.1.1.1 | 62.5% loss at `as13335.saopaulo.sp.ix.br`, destination 0%, clean downstream hops |
| MTR yirukou → github.com (MS) | 4-14% loss every hop, worst MS Rio edge, 6.3% at destination |
| MTR yirukou → globo | clean |
| yirukou `/proc/net/dev` | `enp7s0`/`enp6s0`: 0 rx-errors, ~0 drops → NIC is not the problem |
| yirukou keepalived log | `check_enp7s0 timed_out` → FAULT→BACKUP→MASTER at 11:37, 11:38, 11:42, 11:55, 13:33, 15:38 |
| yifuwuqi keepalived log | `Netlink reports eno1 down` → FAULT→BACKUP→MASTER at 20:12-20:13 |
| eno1 link events | `r8169 ... Link is Down/Up` repeated (physical/EEE/cable issue on the box) |

**Conclusion:** root cause is ISP downstream/peering congestion (Cloudflare SP IX,
Microsoft Rio edge) — *not* the LAN, *not* keepalived. keepalived is a hair-trigger
amplifier: its single-ping probe fails during the same bursts, flips state, and
flushes conntrack, resetting all connections and multiplying perceived loss.

### Current probe/tuning (`modules/networking/gateway-failover.nix`)

- `checkScript`: `ping -I <iface> -c 1 -W 2 -w 5 <pingTarget>` — one packet; a
  single loss = check failure.
- `vrrpScripts`: `interval = 2`, `timeout = pingDeadline (5)`, `rise = 2`, `fall = 2`.
- `notifyScript`: on every state change runs `routeReplace default` then
  `conntrack -F` (`gateway-failover.nix:136`).
- `interval (2) < timeout (5)` → checks overlap ("already running, skipping run").

Probe targets in `modules/addresses.nix`:
- yirukou: `pingTarget = "1.1.1.1"` — sits on the congested SP-IX path.
- yifuwuqi: `pingTarget = "4.2.2.2"`.

## Problems

1. **Probes measure peering congestion, not WAN liveness.** yirukou probes
   `1.1.1.1`, the exact path with 62.5% loss at the IX. A single congested
   peering path is enough to trip failover.
2. **Single ping is a hair trigger.** `-c 1` fails 25% of the time under
   observed loss; `fall = 2` means ~4-6s of loss → FAULT.
3. **`conntrack -F` on every transition** (`gateway-failover.nix:136`) resets
   every LAN connection on each flap — the amplifier. MASTER→FAULT→MASTER
   flushes twice.
4. **Script timeout (5s) > interval (2s)** → overlapping runs, skipped checks.
5. **yifuwuqi `eno1` link flapping is a separate physical issue** (r8169 Link
   Down/Up, MTU 1492 on a LAN port) — noted, out of scope for this plan.

## Decisions

| Concern | Decision |
|---------|----------|
| Ping tolerance | `-c 3 -W 1 -w 3`, succeed if **≥1** reply. Single check fails only if all 3 lost (~1.6%/check at 25% loss). |
| Probe targets | `pingTarget` becomes a **list**; check succeeds if **any** target answers. Keep existing, add `8.8.8.8` to both hosts. |
| Failover latency | `fall = 4` (~8-12s sustained loss before switching); `rise = 2` stays (fast recovery). |
| Script overlap | `timeout = interval + 1` (3s); never overlap, kill "already running, skipping run". |
| Conntrack | Only flush when the installed default gateway actually **changes** (compare `via` vs a state file in `/run`). Skip flush on same-gateway re-assertions. |
| Scope | Apply module-wide in one change; both hosts inherit. |

## File changes

### 1. `modules/networking/gateway-failover.nix`

- **`leaseDiscover`**: unchanged.
- **`checkScript`** (`gateway-failover.nix:77-96`):
  - Loop over `cfg.pingTarget` (list); for each, install the `/32` host route
    and `ping -c 3 -W 1 -w 3`; `exit 0` on the first success, `exit 1` if all fail.
- **`notifyScript`** (`gateway-failover.nix:101-138`):
  - Before `routeReplace`, read the current default route's `via` (e.g. from
    `ip route show default`, or a stamp file under `/run/keepalived-gw`).
  - Replace the default route regardless (route replace is idempotent).
  - Only run `conntrack -F` when the newly installed gateway differs from the
    stamped one; update the stamp.
- **`vrrpScripts`**:
  - `interval = 2`, `timeout = 3` (was `pingDeadline`), `rise = 2`, `fall = 4`.

### 2. `modules/addresses.nix`

- Change `gatewayFailover.pingTarget` (yirukou ~line 607, yifuwuqi ~line 236)
  from a string to a list:
  - yirukou: `[ "1.1.1.1" "8.8.8.8" ]`
  - yifuwuqi: `[ "4.2.2.2" "8.8.8.8" ]`
- Keep `pingTimeout`/`pingDeadline` semantics aligned with the new check (the
  script now hardcodes `-W 1 -w 3`; keep `pingDeadline` ≥ timeout or drop it).

## Rollout order

1. Apply module changes + address list to both hosts.
2. Rebuild **yirukou** first (LAN default gateway, probes the congested path).
   Command for the user: `sudo nixos-rebuild switch --flake .#yirukou`.
3. Observe one congestion burst: keepalived must stay MASTER, no `conntrack -F`,
   LAN connections survive.
4. Rebuild **yifuwuqi**: `sudo nixos-rebuild switch --flake .#yifuwuqi`.
5. Re-run `speedtest-go` + MTR during a burst; confirm perceived loss drops to
   the real ~6-14% (still ISP-side, unchanged by this plan).

## Out of scope (separate track)

- ISP ticket: downstream/peering congestion (Cloudflare SP IX, Microsoft Rio
  edge); upload clean at 783 Mbps, download 25 Mbps with 6-25% loss on those
  paths, Globo unaffected.
- yifuwuqi `eno1` r8169 physical link flapping + MTU 1492-on-LAN-port question.

## Open questions

- Is `fall = 4` (~10s) the right failover latency for a real WAN outage, or do
  you prefer `fall = 3`?
- Should the probe set include each WAN's ISP first-hop gateway (more sensitive
  to link loss, blind to peering), in addition to `8.8.8.8`?
- Separate plan for the yifuwuqi `eno1` r8169/MTU issue?
