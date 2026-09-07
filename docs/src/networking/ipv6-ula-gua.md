# IPv6: ULA now, GUA later

This is the current-state record of why the LAN uses Unique Local Addresses
(`fd75:c55f:6d19::/48`) and why Global Unicast Addresses from the ISP are not
used. Native dual-stack was tried and failed live on 2026-09-06. Missing IPv6
internet egress is intentional until a usable prefix exists, not an unfinished
rollout.

Related: [yirukou edge](yirukou.md), [sysctl and firewall](sysctl-firewall.md),
[implementation plan](../plans/ipv6-enablement-plan.md).

______________________________________________________________________

## 1. What the ISP actually offers

The primary CPE (WAN `enp7s0`) behaves like a single-host IPv6 uplink, not a
delegating router:

| Signal                     | Observed result                                      |
| -------------------------- | ---------------------------------------------------- |
| Router Advertisement       | One WAN `/64` (`2804:229c:8201:145b::/64`)           |
| DHCPv6-PD                  | None                                                 |
| DHCPv6 IA_NA               | A single `/128`, which conflicted with the RA `/64`  |
| Prefix size for LAN + VLAN | Not met (need at least two `/64`s, preferably `/56`) |

A WAN `/64` can address the router itself. It cannot be split onto `br0` and
VLAN 42 without either:

- prefix delegation (absent),
- NPTv6 / NAT66 of that `/64` onto the LAN (rejected: stateful, breaks
  inbound, fights Happy Eyeballs),
- or NDP proxying the CPE prefix onto the LAN (rejected: one `/64` shared
  with the CPE, no isolation, depends on the ISP staying that prefix).

So GUA on the WAN is not a LAN addressing plan. Tailscale's overlay ULA
`fd7a:115c:a1e0::/48` is also not a LAN plan: it cannot be advertised to
physical clients.

______________________________________________________________________

## 2. What broke in the native attempt

The previous config asked the WAN for RA + DHCPv6-PD and let `br0` / VLAN 42
announce whatever prefix arrived. Live state:

- yirukou got a GUA and a temporary address on `enp7s0`, plus an IPv6 default
  route via the CPE. `ping -6 2620:fe::fe` worked **from the router only**.
- `br0` never received a delegated `/64`. It still emitted RA with no prefix.
  LAN clients that accepted RA installed a **dead default route** toward
  yirukou's link-local, with no source address they could use on the internet.
- yifuwuqi `eno1` had that dead default and no GUA. Egress failed.
- nixpkgs systemd-networkd defaults `IPv6PrivacyExtensions = true`, which
  overrode `networking.tempAddresses = "disabled"`. Temporary addresses
  appeared on WAN and LAN anyway.

Public AAAA answers plus a default route with no working path is the classic
Happy Eyeballs stall: clients try IPv6, wait, then fall back to IPv4. That is
worse than IPv4-only.

______________________________________________________________________

## 3. Why ULA, and why no default route

ULA `fd75:c55f:6d19::/48` was already assigned for the DNS sinkhole
(`fd75:c55f:6d19::24`). It is locally chosen and permanent, so full addresses
live in `modules/addresses.nix` instead of being derived from a CPE prefix
that can change or vanish.

| Segment   | Prefix                  | Role                                     |
| --------- | ----------------------- | ---------------------------------------- |
| Sinkhole  | `fd75:c55f:6d19::/64`   | Unadvertised; `/128` on `br0` only       |
| LAN `br0` | `fd75:c55f:6d19:1::/64` | Router `::1`, yifuwuqi `::2`, SLAAC rest |
| VLAN 42   | `fd75:c55f:6d19:2::/64` | Router `::1`, SLAAC; isolated from LAN   |

RA on each segment advertises the on-link prefix and RDNSS with
`RouterLifetimeSec = 0`. Clients get an address and DNS, not an IPv6 default
route. Servers use static ULAs and `IPv6AcceptRA = no`, so a stray CPE RA
cannot install a second address or a default.

Consequences that are load-bearing, not bugs:

- IPv6 never leaves the LAN. WANs have IPv6 disabled (`DHCP = "ipv4"`,
  `IPv6AcceptRA = no`, `LinkLocalAddressing = no`) and nftables drops IPv6
  on those interfaces in prerouting, input, output, and forward.
- Blocked AAAA answers (`fd75:c55f:6d19::24`) are off-link for clients, so
  they fail locally. nft sinkhole rules still apply on yirukou itself.
- Dual-stack **LAN** names (`.lan` / `.local`) can prefer ULA via `gai.conf`.
  Dual-stack **internet** names have no IPv6 route, so they use IPv4 with no
  Happy Eyeballs delay.
- Local DNS transport prefers `[::1]` / LAN ULA and keeps IPv4 as fallback.
  Recursive lookups and filter downloads stay IPv4 because there is no IPv6
  path off-net.

`gai.conf` ranks `fd75:c55f:6d19::/48` above IPv4-mapped, and IPv4-mapped
above `::/0`. Tailscale `fd7a:115c:a1e0::/48` stays low so overlay traffic
keeps preferring IPv4.

______________________________________________________________________

## 4. ULA vs GUA (what each is for)

ULA is for **stable on-net identity**. It does not need the ISP. It does not
provide reachability from the internet. RFC 4193 traffic is not globally
routable; putting ULA on a WAN or NATting it toward the internet is not a
substitute for GUA.

GUA is for **internet IPv6**. It requires a prefix the router can place on
LAN segments (typically DHCPv6-PD `/56` or at least two `/64`s), plus a
default route that actually forwards. A GUA on the WAN NIC alone is not
enough.

Do not mix the two as if they were the same address family policy:

- Do not advertise ULA with a non-zero router lifetime hoping clients will
  "try the internet on IPv6". They will blackhole.
- Do not put GUA on LAN hosts while the only default is the current CPE `/64`
  with no PD. Hosts will source from a prefix the LAN is not on.
- Do not prefer public AAAA (`gai.conf` `::/0` above IPv4) until LAN hosts
  have GUA **and** a working default.

______________________________________________________________________

## 5. WAN IPv6 drop vs bogon filtering

Today all WAN IPv6 is dropped. That makes an IPv6 bogon set unreachable:
prerouting never classifies GUA vs documentation vs ULA spoofing because the
packet is already gone.

That is correct while there is no PD. It is **not** the long-term WAN IPv6
policy. When GUA is enabled, restore a `wan_bogon_v6` set (the previous
contents were appropriate: `::/128`, `::1/128`, `64:ff9b::/96`, `100::/64`,
`2001:db8::/32`, `2002::/16`, `fc00::/7`, `fe80::/10`, `ff00::/8`, plus other
documentation/reserved ranges). Keep `fc00::/7` on that WAN list: ULA must
not appear as a WAN source or destination.

Before bogon matching, allow the link-local ICMPv6 that RA and Neighbor
Discovery need (and DHCPv6-PD if that is how the prefix arrives). Then drop
unsolicited inbound GUA, and only forward the delegated prefix, not the CPE's
on-link WAN `/64`, onto LAN.

______________________________________________________________________

## 6. Gate for turning GUA on

Do not re-enable WAN RA or LAN GUA until **all** of these are true:

1. The CPE or a later ISP path delegates a prefix large enough for every
   advertised segment (`br0` and VLAN 42 today). A WAN-only `/64` still fails
   the gate.
1. The delegated prefix is stable enough to operate, or LAN GUA is treated as
   ephemeral (SLAAC from PD) while ULA stays the Nix-pinned service address.
1. `gai.conf` is revisited: GUA should outrank IPv4 for destinations that
   have both, **without** ranking dead `::/0` over IPv4 before the default
   route works. ULA should remain preferred for on-net names that have AAAA.
1. Monitoring's probe peers are dual-stack, but `monitoring.ipv6Egress` is
   `false`, so internet peers are probed over IPv4 only and the v4/v6
   comparison runs on the `lan` scope (see
   [monitoring](../services/monitoring.md)). Flipping that flag to `true` is
   part of passing this gate: it restores public `icmp6` / `dns6` / `http6`
   against the same peers as IPv4, plus the matching smokeping targets.
1. Happy Eyeballs is tested from a LAN client to a dual-stack public name.
   If IPv6 is slower or blackholes, keep IPv4 preference until it does not.

Out of scope unless explicitly redesigned: NAT66, NPTv6, NDP-proxy of the CPE
`/64`, tunnel brokers, and advertising GUA or ULA into Tailscale.

ULA stays even after GUA exists. Service binds, RDNSS, `.lan` / `.local`
AAAA, and the sinkhole should not jump to a prefix the ISP can withdraw.
