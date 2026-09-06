# IPv6 Enablement Plan (yirukou + yifuwuqi)

## Status

**The previous native dual-stack design was deployed and failed live
verification. The ULA revision is implemented in the working tree and awaits
deployment and live verification.**

DHCPv6-PD is abandoned. The primary CPE advertises a WAN `/64` by RA and
offers a single `/128` by DHCPv6, but delegates no prefix, so the project
gate requiring at least two `/64`s was never met. Native IPv6 is now out of
scope: no IPv6 internet egress, no global addresses on any interface, and no
dependency on the ISP, a VPS, or a tunnel broker.

Tailscale is not part of the IPv6 address plan. Its overlay ULA
`fd7a:115c:a1e0::/48` remains as-is for mesh hosts, but it cannot be handed
to physical LAN clients, so it does not solve LAN addressing. Tailscale
subnet routing and exit-node use stay IPv4-only exactly as today.

Implementation choices:

- use the static ULA `fd75:c55f:6d19::/48` already used for the sinkhole;
- give each segment one statically configured `/64`; nothing is delegated;
- advertise prefix and RDNSS by RA with router lifetime `0`, so clients
  autoconfigure addresses and DNS but install no IPv6 default route;
- give both servers static addresses instead of having them accept RA;
- remove IPv6 from both yirukou WANs and from yifuwuqi's fallback and Wi-Fi;
- keep IPv4 as the only internet transport, with NAT44, DHCPv4, keepalived
  failover, nginx, Valkey, and monitoring unchanged.

## Live verification of the previous attempt (2026-09-06)

| Check                                   | Result                                                                         |
| --------------------------------------- | ------------------------------------------------------------------------------ |
| yirukou `enp7s0` global address         | present by SLAAC (`2804:229c:8201:145b:…`), plus a temporary address           |
| yirukou DHCPv6 prefix delegation        | none; only a conflicting `/128` address offer                                  |
| yirukou `br0` / VLAN 42 delegated `/64` | never assigned; only link-local and the sinkhole `/128`                        |
| yirukou IPv6 egress                     | `ping -6 2620:fe::fe` succeeded from the router only                           |
| yifuwuqi `eno1` global address          | none, despite an RA default route via `br0`'s link-local                       |
| yifuwuqi IPv6 egress                    | failed, as expected with no usable source address                              |
| privacy addresses                       | active (`use_tempaddr = 2`) on both hosts despite `tempAddresses = "disabled"` |
| yirukou AdGuard DNS bind                | `::` wildcard, relying entirely on the firewall for WAN exposure               |
| Unbound `::1` listener and AAAA answers | working on both hosts                                                          |
| blocked AAAA sinkhole answer            | correct (`fd75:c55f:6d19::24`)                                                 |
| fallback WAN IPv6 isolation             | correct; no address and no route                                               |

Two findings carry into this revision. Privacy addresses were enabled
because systemd-networkd defaults `IPv6PrivacyExtensions` to true in
nixpkgs, which overrides `networking.tempAddresses = "disabled"`. The RA
that yirukou emitted with no prefix gave every RA-accepting LAN client a
dead IPv6 default route pointing at a router with no usable path.

## Objective and scope

Provide stable, prefix-independent IPv6 addressing on the LANs yirukou
serves, for host-to-host and host-to-service traffic only. IPv6 never leaves
the LAN. Because the prefix is locally assigned and permanent, complete
addresses can live in Nix instead of being derived from a delegated prefix.

In scope:

- yirukou LAN bridge `br0` and VLAN 42: static ULA `/64` plus RA;
- yifuwuqi `eno1`: static ULA address;
- removal of all IPv6 from yirukou `enp7s0` and `enp6s0`;
- Unbound and AdGuard listeners, address-selection policy, sinkhole,
  firewall, and monitoring for those paths.

Intentionally out of scope:

- any form of IPv6 internet egress, including NAT66, NPTv6, NDP proxying of
  the CPE `/64`, tunnel brokers, and IPv6 through Tailscale exit nodes;
- DHCPv6 service for LAN clients; clients use SLAAC and RDNSS;
- IPv6 Tailscale/NetBird subnet advertisement;
- converting Valkey, nginx backends, Prometheus scrapes, or the `.lan`,
  `.local`, `.ts`, and `.nb` wildcard answers away from IPv4;
- yixiaoqing and yitaishi, which keep importing the common IPv6 policy
  module and will autoconfigure a LAN ULA when physically connected.

## Address and routing design

- `fd75:c55f:6d19::/48` is locally assigned and permanent. Full addresses,
  not interface identifiers, belong in `modules/addresses.nix`.
- `fd75:c55f:6d19::/64` stays unadvertised and holds only the existing
  sinkhole address, which does not change.
- Each served segment gets its own advertised `/64`.
- RA carries the on-link prefix and RDNSS with `RouterLifetimeSec = 0`.
  Clients therefore get an address and a DNS server but no IPv6 default
  route, which is what keeps IPv6 confined to the LAN.
- Both servers are statically configured and accept no RA, so no stray
  upstream advertisement can install a default route or a second address.
- RDNSS advertises yirukou's static segment address rather than its
  link-local address. Because it is stable and expressible in Nix, AdGuard
  can bind explicit addresses instead of the `::` wildcard.
- DHCPv4 keeps advertising the static IPv4 DNS servers.
- No NAT66, no NPTv6, no IPv6 default route on any interface.

| Segment             | Prefix                  | Router                | Server                | Clients        |
| ------------------- | ----------------------- | --------------------- | --------------------- | -------------- |
| LAN (`br0`)         | `fd75:c55f:6d19:1::/64` | `fd75:c55f:6d19:1::1` | `fd75:c55f:6d19:1::2` | SLAAC          |
| Untrusted (VLAN 42) | `fd75:c55f:6d19:2::/64` | `fd75:c55f:6d19:2::1` | —                     | SLAAC          |
| Sinkhole only       | `fd75:c55f:6d19::/64`   | `fd75:c55f:6d19::24`  | —                     | not advertised |

Because clients have no IPv6 default route, a blocked AAAA answer of
`fd75:c55f:6d19::24` is off-link and unreachable, so the client fails
immediately and locally without a round trip. This replaces the previous
mechanism, where the answer was expected to reach yirukou and be rejected by
nftables. The static nftables sinkhole rules stay for hosts that can route
to the address, which is yirukou itself.

There is no longer any prefix-size gate, project gate, or CPE dependency.

## Phase A — remove ISP-dependent IPv6

1. In `hosts/yirukou/networking/wans.nix`, set both WANs to `DHCP = "ipv4"`
   with `IPv6AcceptRA = "no"` and `LinkLocalAddressing = "no"`. Delete
   `dhcpV6Config`, `PrefixDelegationHint`, and `ipv6AcceptRAConfig`.

1. In `hosts/yirukou/networking/firewall.nix`, drop IPv6 unconditionally on
   both WAN interfaces for input, output, and forwarding. Remove the
   raw-prerouting link-local exemption chain for RA, ND, and DHCPv6, the
   LAN-to-primary-WAN IPv6 forward accept, and the unsolicited-inbound IPv6
   rule, all of which existed only to support WAN RA and PD.

1. In `modules/networking/ipv6.nix`, set
   `systemd.network.config.networkConfig.IPv6PrivacyExtensions = false` so
   the declared `networking.tempAddresses = "disabled"` is actually honored,
   and rewrite the address-selection policy so that the local ULA outranks
   IPv4, and IPv4 outranks all remaining IPv6:

   - `fd75:c55f:6d19::/48` above IPv4-mapped addresses;
   - IPv4-mapped addresses above `::/0`;
   - Tailscale's `fd7a:115c:a1e0::/48` left at its low default precedence so
     tailnet traffic keeps preferring IPv4, as documented today.

1. Keep `net.ipv6.conf.all.forwarding = 1` in
   `hosts/yirukou/networking/sysctl.nix`. It is still required for Tailscale
   and for routing between the two LAN ULA segments.

1. Apply yirukou and confirm no interface has a global address, temporary
   address, or IPv6 default route.

```sh
ip -6 address show
ip -6 route show
networkctl status enp7s0 enp6s0
```

## Phase B — yirukou LAN and VLAN ULA

1. In `modules/addresses.nix`, replace `lan.ipv6.interfaceId` and
   `untrusted.ipv6.interfaceId` with complete `host`, `prefixLength`,
   `address`, and `cidr` fields for both segments on both hosts. Leave
   `sinkhole.ipv6.host` unchanged.

1. In `hosts/yirukou/networking/bridge.nix`, configure `br0` with:

   - `LinkLocalAddressing = "ipv6"` and `IPv6Forwarding = true`;
   - `IPv6AcceptRA = "no"`;
   - the static `fd75:c55f:6d19:1::1/64` address, keeping the existing IPv4
     addresses and the sinkhole `/128`;
   - `IPv6SendRA = true` with `ipv6SendRAConfig.RouterLifetimeSec = 0`,
     `EmitDNS = true`, and `DNS = "fd75:c55f:6d19:1::1"`;
   - no `DHCPPrefixDelegation` and no `dhcpPrefixDelegationConfig`; delete
     the `UplinkInterface`, `SubnetId`, `Token`, `Announce`, and `Assign`
     settings entirely.

   Bridge member ports keep link-local addressing disabled.

1. Apply the same static design to VLAN 42 in
   `hosts/yirukou/networking/untrusted.nix` using
   `fd75:c55f:6d19:2::1/64` and its own RDNSS value. The VLAN parent
   `enp2s0` keeps link-local addressing disabled.

1. Extend `hosts/yirukou/networking/firewall.nix` so IPv6 matches the
   existing IPv4 posture rather than inheriting a router-only default:

   - allow LAN and VLAN ULA traffic to yirukou's own services on the same
     terms as IPv4;
   - mirror the IPv4 untrusted-VLAN isolation for `ip6`, so VLAN 42 cannot
     reach the LAN `/64`;
   - keep required ICMPv6 on internal interfaces;
   - keep the MagicDNS `fd7a:115c:a1e0::53` DNS-interception exemption;
   - replace the delegated-IID DNS exemption for yifuwuqi with a plain
     match on `fd75:c55f:6d19:1::2`, which is now static.

1. Replace yirukou's `dnsBindHosts = [ "::" ]` in `modules/addresses.nix`
   with an explicit list: IPv4 loopback and LAN addresses, the Tailscale
   address, `::1`, and both segment ULAs. The wildcard existed only because
   the RDNSS targets were rotating link-local addresses; static ULAs remove
   that constraint and stop AdGuard from binding WAN addresses at all.

1. Verify a LAN client and a VLAN 42 client independently. Each must
   autoconfigure an address in its own `/64`, receive the segment RDNSS
   address, and have no IPv6 default route.

## Phase C — yifuwuqi and DNS

1. In `hosts/yifuwuqi/networking/interfaces/eno1.nix`, add the static
   address `fd75:c55f:6d19:1::2/64`, set `LinkLocalAddressing = "ipv6"`, and
   set `IPv6AcceptRA = "no"`. Remove `ipv6AcceptRAConfig` and its `Token`.
   This eliminates the dead RA default route observed during verification.

1. Keep IPv6 disabled on yifuwuqi `enp4s0` and `wlp2s0`.

1. In `modules/services/unbound.nix`, keep `do-ip6 = "yes"`, the `::1`
   listener, and `::1/128 allow`. Setting `do-ip6 = "no"` would also disable
   the `::1` listener that AdGuard uses as `[::1]:5335`. Outbound IPv6
   resolution stops on its own because neither host has an IPv6 default
   route.

1. In `modules/services/adguardhome.nix`, set
   `bootstrap_prefer_ipv6 = false`, keep `ipv6_disabled = false` so ULA AAAA
   answers still work, and keep `blocking_ipv6` pointed at
   `fd75:c55f:6d19::24`. Use `[::1]:5335` as the primary upstream and
   `127.0.0.1:5335` as fallback, so the local AdGuard-to-Unbound hop prefers
   IPv6 without losing IPv4 support. List IPv6 before IPv4 for bootstrap and
   local PTR queries.

1. Add `fd75:c55f:6d19:1::2` to yifuwuqi's explicit `dnsBindHosts` list.

1. Add AAAA answers for the per-host `.lan` and `.local` names so internal
   names resolve to the LAN ULA. Leave the `fufu.land` and `*.fufu.land`
   wildcards IPv4-only, because nginx and its backends stay on IPv4.

1. Prefer IPv6 for host DNS queries. On yifuwuqi, order system nameservers as
   `fd75:c55f:6d19:1::1`, `::1`, then the existing IPv4 servers. On yirukou,
   order them as `::1`, then `127.0.0.1`. RDNSS advertises the segment ULA to
   SLAAC clients. Kea DHCPv4 option 6 remains IPv4-only because it cannot
   carry IPv6 addresses.

1. Deploy the shared Unbound and AdGuard changes to yirukou first, verify,
   then yifuwuqi. Both hosts import these modules, so a shared edit is never
   a single-host change.

## Phase D — verification

1. No interface on either host has a global address, a temporary address, or
   an IPv6 default route. Both WANs and yifuwuqi's fallback and Wi-Fi links
   have no IPv6 address at all.
1. Both servers reach each other over the LAN ULA, in both directions.
1. A LAN client and a VLAN 42 client each autoconfigure an address and receive
   the correct RDNSS. The LAN client reaches both servers over IPv6. The VLAN
   client reaches yirukou on its segment ULA but cannot reach yifuwuqi or the
   LAN `/64`, matching the existing untrusted-segment isolation.
1. `ping -6 2620:fe::fe` fails from every host. This is the intended result,
   not a regression.
1. `dig @127.0.0.1 AAAA github.com` and `dig @::1 AAAA github.com` still
   work, DNS reaches AdGuard over the LAN ULA on both hosts, and the system
   resolver lists ULA or `::1` before IPv4.
1. Public dual-stack destinations are contacted over IPv4, while internal
   names carrying an AAAA record are contacted over the ULA.
1. A blocked AAAA query returns `fd75:c55f:6d19::24` and fails immediately
   on the client for lack of a route.
1. AdGuard filter downloads still succeed over IPv4, and no AdGuard or
   Unbound listener is bound to a WAN address.
1. IPv4 WAN failover on yirukou and yifuwuqi's `enp4s0` fallback behave
   exactly as before; LAN IPv6 is unaffected by either transition, because
   it does not depend on any uplink.
1. Evaluate both configurations before each deployment.

## Global IPv6/IP6 audit

| Existing setting / alias                 | Final state                                                     |
| ---------------------------------------- | --------------------------------------------------------------- |
| yirukou primary WAN RA/DHCPv6-PD         | removed; IPv4-only                                              |
| yirukou fallback WAN RA/DHCPv6           | remains disabled                                                |
| yirukou WAN ICMPv6/ND/DHCPv6 exemptions  | removed with WAN IPv6                                           |
| yirukou `br0` and VLAN 42                | static ULA `/64`, RA with router lifetime 0, IPv6 forwarding    |
| bridge member ports / VLAN parent        | link-local disabled intentionally                               |
| yifuwuqi `eno1`                          | static ULA `::2`; accepts no RA                                 |
| yifuwuqi `enp4s0`, `wlp2s0`              | IPv6 disabled intentionally                                     |
| `networking.enableIPv6`                  | enabled on both hosts                                           |
| address-selection policy                 | local ULA above IPv4, IPv4 above all other IPv6                 |
| temporary/privacy IPv6 addresses         | disabled for real, via networkd `IPv6PrivacyExtensions = false` |
| Unbound `do-ip6`, loopback `::1`, ACL    | retained; outbound IPv6 dies with the default route             |
| AdGuard `ipv6_disabled`                  | stays false so ULA AAAA works                                   |
| AdGuard → Unbound                        | `[::1]:5335` primary; IPv4 loopback fallback                    |
| AdGuard DNS bind                         | explicit addresses only; `::` wildcard removed                  |
| AdGuard `bootstrap_prefer_ipv6`          | false                                                           |
| AdGuard rewrites                         | per-host `.lan`/`.local` gain AAAA; wildcards stay IPv4         |
| Host resolver order                      | LAN ULA / `::1` before IPv4                                     |
| Sinkhole `ip6` / ICMPv6 rules            | address unchanged; now unreachable client-side by design        |
| `.lan`, `.local`, `.ts`, `.nb` aliases   | IPv4 answers retained                                           |
| Kea DHCPv4 / SLAAC / RDNSS               | DHCPv4 retained; no DHCPv6 server                               |
| keepalived                               | IPv4-only intentionally                                         |
| Tailscale/NetBird route advertisement    | IPv4-only intentionally; overlay IPv6 untouched                 |
| IPv6 internet egress                     | none, by design                                                 |
| qBittorrent VPN `disable_ipv6=1`         | retained                                                        |
| SSH `listenWildcardIPv6 = null`          | retained                                                        |
| yifuwuqi firewall `ip` rules             | retained; explicit `ip6` additions only where required          |
| nginx proxy/backend and Valkey transport | retained on static IPv4                                         |
| Podman `ipv6_enabled = true`             | already enabled                                                 |
| Avahi `nssmdns6 = true`                  | already enabled; now resolves ULA                               |
| ICMP/DNS/HTTP monitoring probes          | public IPv6 probes removed; ULA probes added                    |

## Monitoring

Public IPv6 targets in `modules/addresses.nix` and the `http6` module in
`modules/services/monitoring/blackbox.yml` must be removed: they would fail
permanently by design and generate noise. Keep the IPv6-forcing `icmp6` and
`dns6` blackbox modules but point them at `fd75:c55f:6d19:1::1` and
`fd75:c55f:6d19:1::2` and at a local AAAA query, so the probes assert LAN
ULA reachability instead of internet reachability. All existing IPv4 probes
stay.

## Failure behavior

LAN IPv6 no longer depends on any uplink, so WAN failover cannot withdraw
addresses or prefixes from clients, and the RA lifetime concerns from the
delegated-prefix design no longer apply. Losing an uplink affects IPv4 only.

Because clients hold no IPv6 default route, they never attempt IPv6 for
internet destinations, so there is no Happy Eyeballs delay to mitigate. The
only IPv6 failure mode left is a local one: if yirukou stops advertising a
segment, clients keep their address until the prefix lifetime expires and
lose nothing else, since IPv4 carries all external traffic.

## Rollout order

Phase A yirukou WAN IPv6 removal and policy → Phase B yirukou LAN and VLAN
ULA with RA → Phase C yifuwuqi and DNS → Phase D verification. Apply and
verify each phase before continuing. Shared DNS module changes go to yirukou
first.

## Documentation follow-up

After implementation, update current-state documentation, describing an
intentionally egress-free LAN IPv6 fabric rather than an incomplete native
rollout:

- `docs/src/networking/yirukou.md`
- `docs/src/networking/ipv6-ula-gua.md`
- `docs/src/networking/sysctl-firewall.md`
- `docs/src/hosts/yirukou.md`
- `docs/src/hosts/yifuwuqi.md`
- `docs/src/services/dns-and-proxy.md`
- `docs/src/services/monitoring.md`

Keep IPv4-only components documented as intentional, and record that no IPv6
egress exists so a future reader does not treat it as a missing feature.
