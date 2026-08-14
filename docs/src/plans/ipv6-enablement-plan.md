# IPv6 Enablement Plan (yirukou + yifuwuqi)

Goal: enable IPv6 end-to-end on the LAN served by `yirukou` (router/gateway) and consumed by `yifuwuqi` (DNS server). This is infrastructure work — it is **not** required to fix the 2026-08-14 DNS incident (see `docs/src/plans/adguard-default-filter-fix-plan.md`).

## Research Findings (2026-08-14, verified on yirukou)

1. **Neither WAN receives IPv6 today**:
   - `enp7s0` (primary WAN, `192.168.1.43/24` via CPE `192.168.1.1`) and `enp6s0` (fallback WAN, `192.168.8.117/24` via CPE `192.168.8.1`) have **only link-local IPv6** (`fe80::…`), no global address, no IPv6 default route.
   - The CPEs are consumer routers/modem-routers; whether the ISP delivers IPv6 to them is **unknown and must be checked first**.
2. **Kernel blocks RA processing on the WANs**:
   - `net.ipv6.conf.all.forwarding = 1` (present in `/etc/sysctl.d/60-nixos.conf`; origin not identified in this repo — treat as needed anyway for a router) forces `net.ipv6.conf.enp7s0.accept_ra = 0` / `enp6s0.accept_ra = 0`, so even if the CPEs sent router advertisements, the kernel would ignore them.
   - Fix: `accept_ra = 2` (accept RAs even when forwarding) on both WANs.
3. `netbird` is inactive on yirukou — ignored.
4. yirukou's LAN: `br0 = 10.42.0.1/24` (DHCP pool `.100–.250`, kea), untrusted VLAN 42 `10.42.42.0/24`, IPv6 disabled (`LinkLocalAddressing = "no"`, `IPv6AcceptRA = "no"`).
5. `modules/networking/sinkhole.nix` already carries `ip6` nftables rules for the sinkhole addresses (currently the `2001:db8::1` / `2001:db8::2` placeholders — RFC 5737 documentation ranges, replaced below).
6. Firewall groundwork exists on yirukou (`wanBogonV6Set`, ICMPv6 rules in `hosts/yirukou/networking/firewall.nix`); yifuwuqi's firewall rules are `family = "inet"` (cover v6 already).
7. keepalived (`modules/networking/gateway-failover.nix`) is IPv4-only; IPv6 WAN failover is deferred.
8. yirukou's SSH host key changed at some point — known_hosts entry for `[100.69.0.1]:24212` is stale (LAN IP entry `[10.42.0.1]:24212` is correct). Clean up known_hosts when convenient.

## IPv6 Subnet Design

IPv6 has no NAT and no private ranges: each LAN segment gets exactly one `/64`, and the prefix **comes from the ISP** via DHCPv6-PD through the CPE. Nothing is invented by us except the low-order bits.

### Prefix allocation (once a PD is confirmed)

| Segment | /64 | Router (::1) | Servers | Sinkhole | DHCPv6/SLAAC |
|---|---|---|---|---|---|
| LAN (`br0`, 10.42.0.0/24) | `<PD>/64` | yirukou | yifuwuqi `::2` | `::24` | clients `::100–::250` |
| Untrusted (VLAN 42, 10.42.42.0/24) | `<PD+1>/64` | yirukou | — | `::24` | clients `::100–::250` |
| Spare | `<PD+2..N>/64` | future segments | | | |

Host suffixes mirror the IPv4 numbering (`10.42.0.1 → ::1`, `.2 → ::2`, `.24 → ::24`) for easy correlation. If the PD is smaller than `/60`, drop the spare segments and keep only LAN + untrusted. If the ISP grants only a single `/64` (no PD), see the decision tree.

### Decision tree (which outcome applies)

| CPE/ISP outcome | Approach |
|---|---|
| CPE gets IPv6 + delegates a prefix (PD) to yirukou | Full rollout (Phases A–D below) |
| CPE gets IPv6 but only SLAAC `/64` on its own LAN (no PD to yirukou) | yirukou becomes a v6 *host* on the CPE /64; its own LAN cannot get global IPv6 → either NAT66 (not recommended) or ULA-only (no internet v6) → stop |
| No IPv6 anywhere | Tunnel broker or VPN-with-v6 (e.g. WARP) + NAT66, or drop the project |

**Step 0 (user, on the CPEs):** log into the CPE admin panels (`192.168.1.1`, `192.168.8.1`) and check the IPv6/WAN status page for a delegated prefix. Consumer CPEs rarely delegate a prefix to a downstream router — this check decides the whole project.

## Phase A — yirukou: receive IPv6 on WANs (test first)

1. **`hosts/yirukou/networking/sysctl.nix`**: add
   - `net.ipv6.conf.all.forwarding = 1` (explicit; already effective, make it owned)
   - `net.ipv6.conf.default.forwarding = 1`
   - `net.ipv6.conf.enp7s0.accept_ra = 2` and `net.ipv6.conf.enp6s0.accept_ra = 2`
2. **`hosts/yirukou/networking/wans.nix`**: keep `IPv6AcceptRA = "yes"`; add DHCPv6-PD:
   - `dhcpV6Config.PrefixDelegation = true` (+ `PrefixDelegationHint` if the ISP advertises a size)
3. Apply (`nixos-rebuild switch --flake .#yirukou`) and watch:
   ```
   watch -n2 'ip -6 addr show enp7s0 enp6s0; ip -6 route show'
   journalctl -u systemd-networkd -f
   ```
   Expected on success: a global address on the WAN, an IPv6 default route, and a delegated prefix (visible as `/56`-style route or networkd journal entries). No success after a few minutes → CPE/ISP does not deliver IPv6 → stop and use the decision tree.

## Phase B — yirukou: route and serve IPv6 on LAN

1. **`hosts/yirukou/networking/bridge.nix`** (`br0`): `LinkLocalAddressing = "yes"`, `IPv6Forwarding = true`, assign the delegated `/64` (`lan.ipv6.address`), `IPv6SendRA = true` with the prefix + RDNSS (point clients at the LAN DNS servers' IPv6 addresses).
2. **`hosts/yirukou/networking/untrusted.nix`** (VLAN 42): same treatment with `<PD+1>/64`.
3. **`modules/addresses.nix`**: add `yirukou.network.lan.ipv6` and `yirukou.network.untrusted.ipv6` (from the PD); replace sinkhole placeholders — `2001:db8::1` (yifuwuqi) and `2001:db8::2` (yirukou) — with the real sinkhole addresses (`lan::24` / `untrusted::24`).
4. **`hosts/yirukou/networking/firewall.nix`**: extend the LAN/internal sets to ip6, allow WAN established/related + essential ICMPv6 (ND, MLD — partially present), keep the bogon v6 drop.
5. **`hosts/yirukou/services.nix`**: `adguardhome.dnsBindHosts` += `br0` IPv6 address.
6. Verify a LAN client (phone/laptop) receives a global IPv6 + default route via RA and can ping `2620:fe::fe`.

## Phase C — yifuwuqi: consume IPv6

1. **`hosts/yifuwuqi/networking/interfaces/eno1.nix`**: `IPv6AcceptRA = "yes"`, `LinkLocalAddressing = "yes"` → SLAAC from yirukou's RA.
2. **`modules/addresses.nix`**: add `yifuwuqi.network.lan.ipv6`; `adguardhome.dnsBindHosts` += the IPv6 address. With working IPv6, `bootstrap_prefer_ipv6 = true` and the Quad9 IPv6 bootstrap (`2620:fe::fe`) finally function as intended.
3. **`hosts/yifuwuqi/networking/interfaces/enp4s0.nix`**: keep IPv6 disabled (fallback uplink owned by keepalived, IPv4-only).
4. Verify: `ip -6 addr`, `ping6 2620:fe::fe`, `dig @127.0.0.1 AAAA github.com` returns a record, filter-list downloads work over IPv6.

## Phase D — End-to-end verification

1. `ip -6 addr` / `ip -6 route` on both hosts show global addresses and a default route.
2. `ping6 2620:fe::fe` from both hosts.
3. `dig @127.0.0.1 AAAA github.com` returns an AAAA record.
4. LAN client reaches an IPv6-only service (e.g. `ping6 2606:4700:4700::1111`).
5. AdGuard Home binds IPv6 (`curl http://127.0.0.1:3333/control/dns_info`) and bootstrap prefers IPv6.

## Deferred / Risks

- **keepalived IPv6 WAN failover**: `gateway-failover.nix` is IPv4-only; accept a brief IPv6 outage on WAN failover (document it).
- **CPE delegation is the likely blocker**: consumer CPEs (MiWiFi-class) generally do not delegate prefixes to downstream routers; if the ISP delivers IPv6 only to the CPE, yirukou's LAN can still get a global `/64` only via NAT66 (undesirable) — treat the Step 0 result as the project gate.
- All privileged steps (`nixos-rebuild`, sysctl tests) are run by the user; the assistant has no sudo on any host.

## Rollout order

Step 0 (CPE check) → Phase A (WAN receive, test) → Phase B (LAN route/serve) → Phase C (yifuwuqi) → Phase D (verify). Each phase applies and verifies before the next.
