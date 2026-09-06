# IPv6 Enablement Plan (yirukou + yifuwuqi)

## Status

**IMPLEMENTED IN CONFIGURATION — not applied or runtime-verified.** Phases A-C
are declared. Phase D and the CPE/ISP delegation gate still require staged
deployment and live validation.

Implementation choices:

- request a `/56` PD hint; the CPE may return another size, but rollout stops
  unless at least two `/64`s are delegated;
- use subnet IDs `0` (`br0`) and `1` (VLAN 42);
- use static ULA `fd75:c55f:6d19::24/128` for IPv6 sinkholing, assigned only
  on yirukou and not advertised by RA;
- keep AdGuard administration on IPv4 while DNS listens on IPv4 and IPv6;
- include DHCPv6 replies from a link-local server in the primary-WAN raw-chain
  exemption, in addition to essential ICMPv6;
- solicit DHCPv6-PD independently of upstream RA M/O flags;
- enforce fallback isolation and unsolicited-inbound policy in a pre-filter
  chain before the NixOS firewall's general ICMPv6 accepts.

## Objective and scope

Enable native dual-stack networking through yirukou's primary WAN and on the
LANs it serves. Native IPv6 is preferred by RFC 6724 address selection when it
is usable; existing static IPv4 addresses, DHCPv4, NAT44, and IPv4 failover
remain available.

IPv6 addressing uses a dynamic ISP-delegated prefix with stable interface IDs:

- yirukou router: `<delegated-/64>::1`
- yifuwuqi server: `<delegated-/64>::2`

Here `::1` and `::2` are host tokens appended to a delegated `/64`. They are
not complete addresses, and router token `::1` is not IPv6 loopback `::1/128`.
The full global addresses change if the ISP rotates the prefix. The sinkhole
uses the prefix-independent ULA `fd75:c55f:6d19::24/128`.

In scope:

- yirukou primary WAN `enp7s0`, LAN bridge `br0`, and VLAN 42;
- yifuwuqi LAN interface `eno1`;
- shared Unbound and AdGuard Home IPv6 transport and listeners;
- firewall, address-model, monitoring, and failover verification needed for
  those paths.

Intentionally out of scope:

- IPv6 on fallback WANs `enp6s0` and yifuwuqi `enp4s0`;
- DHCPv6 service for LAN clients, NAT66, or an IPv6 tunnel broker;
- IPv6 Tailscale/NetBird subnet advertisement;
- converting Valkey, nginx backends, internal DNS rewrites, or all monitoring
  traffic from IPv4 when retained IPv4 is sufficient;
- yixiaoqing and yitaishi rollout details, although both already import the
  common IPv6 policy module and may receive LAN RA when connected.

## Verified pre-implementation repository state

1. Neither yirukou WAN interface had a global IPv6 address or IPv6 default
   route when last checked. Only primary `enp7s0` is in scope. Its
   last-observed CPE was `192.168.1.1`, but the current gateway must be read
   from the live DHCP lease rather than assumed from the repository. `enp6s0`
   stays IPv4-only.
1. yirukou already has `net.ipv6.conf.all.forwarding = 1` at runtime because
   the NixOS Tailscale module sets it when `useRoutingFeatures` is `server` or
   `both`. `yi.tailscale.routingMode = "both"` selects that mode. The final
   configuration owns global forwarding explicitly. systemd-networkd receives
   RA in userspace, and `IPv6AcceptRA = "yes"` maps its managed interface to
   the required kernel behavior; no separate `accept_ra = 2` sysctl is needed.
1. `hosts/yirukou/networking/wans.nix` currently sets
   `IPv6AcceptRA = "yes"` on both WANs, but `DHCP = "ipv4"` starts no DHCPv6
   client. The primary needs RA plus DHCPv6-PD; the fallback must explicitly
   disable RA.
1. yirukou's `br0` and VLAN 42 interfaces disable IPv6 link-local addressing.
   yifuwuqi's `eno1`, `enp4s0`, and `wlp2s0` reject RA; only `eno1` is in scope
   to change.
1. `modules/services/unbound.nix` explicitly sets `do-ip6 = "no"` and listens
   only on `127.0.0.1`. `modules/services/adguardhome.nix` already has
   `ipv6_disabled = false`, but uses IPv4 loopback for Unbound and has
   `bootstrap_prefer_ipv6 = false`.
1. `modules/networking/sinkhole.nix` already has IPv6 nftables rules.
   `2001:db8::/32` is an RFC 3849 documentation prefix, so its current
   `2001:db8::1` and `2001:db8::2` placeholders must not survive rollout.
1. The yirukou raw-prerouting bogon set drops `fe80::/10` on WAN. Upstream
   router advertisements and neighbor discovery use link-local source
   addresses, so essential ICMPv6 must be accepted before that drop on the
   primary WAN. The normal NixOS firewall already admits core ICMPv6 in its
   filter chain, but that happens after this raw-prerouting rule.
1. Kea is DHCPv4-only. No DHCPv6 server is required: LAN clients use SLAAC and
   RDNSS. There is no IPv6 equivalent of the IPv4 `.100-.250` pool.
1. `modules/networking/ipv6.nix` enables IPv6, disables privacy addresses, and
   gives native IPv6 higher RFC 6724 precedence than IPv4-mapped addresses.
   yifuwuqi imports it; yirukou currently does not.
1. `modules/addresses.nix` has no LAN IPv6 schema. Its `.lan`, `.local`, `.ts`,
   and `.nb` aliases point to IPv4 fields, both AdGuard `dnsBindHosts` lists are
   IPv4-only, and the sinkhole values are RFC 3849 placeholders.
1. yifuwuqi's firewall trust and container rules use IPv4 `ip saddr`/`ip daddr` expressions. Its keepalived-managed default route and fallback
   `enp4s0` path are IPv4-only.
1. `modules/services/adguardhome.nix` uses IPv4-only admin and DNS upstream
   endpoints. Its local rewrites return IPv4 addresses. nginx proxies to
   yifuwuqi over IPv4, and Valkey listens on yifuwuqi's static IPv4 LAN
   address.
1. `modules/addresses.nix` internet probes and
   `modules/services/monitoring/blackbox.yml` are IPv4-preferred and test DNS
   type A. The Unbound dashboard can display IPv6 query counters, but no
   automated IPv6 path probe exists.

## Address and routing design

- The ISP delegates a prefix to yirukou over `enp7s0` using DHCPv6-PD.
- systemd-networkd automatically assigns one `/64` to `br0` and one `/64` to
  VLAN 42 and advertises them using RA.
- Ordinary clients receive addresses, routes, and DNS information
  automatically through SLAAC/RDNSS.
- Only delegated interface IDs are fixed: yirukou `::1` and yifuwuqi `::2`.
  Use networkd's `dhcpPrefixDelegationConfig.Token` and `Assign` so the
  delegated prefix remains automatic.
- Advertise yirukou's link-local address as RDNSS using networkd's
  `ipv6SendRAConfig.DNS = "_link_local"` instead of embedding a rotating GUA.
  Existing DHCPv4 continues to advertise the static IPv4 DNS servers.
- Bind services that may receive traffic on a rotating GUA to IPv6 wildcard
  or link-local addresses and use the firewall as the exposure boundary.
- AdGuard `blocking_ipv6` uses static ULA `fd75:c55f:6d19::24`. yirukou
  assigns it as `/128` on `br0`; yifuwuqi returns the same DNS answer but does
  not assign it, avoiding duplicate-address detection.
- The ULA prefix is not advertised as on-link in RA. Dual-stack clients send
  it to their default router, where yirukou's nftables input chain rejects it.
- Do not leave `2001:db8::/32` placeholders active.
- No NAT66.

| Segment             | Delegated prefix | Router token | Server token | Clients |
| ------------------- | ---------------- | ------------ | ------------ | ------- |
| LAN (`br0`)         | first `/64`      | `::1`        | `::2`        | SLAAC   |
| Untrusted (VLAN 42) | second `/64`     | `::1`        | —            | SLAAC   |
| Spare               | remaining `/64`s | —            | —            | —       |

The separate sinkhole address is `fd75:c55f:6d19::24/128`.

The PD must contain at least two `/64`s for both current segments. A single
upstream `/64` cannot be routed onto both LANs without an undesirable
workaround.

### Project gates

Read the current primary gateway with `networkctl status enp7s0` or
`networkctl dhcp-lease enp7s0`, then check that CPE and the ISP:

| Primary CPE/ISP result                   | Action                                    |
| ---------------------------------------- | ----------------------------------------- |
| Delegates at least two `/64`s to yirukou | Continue with Phases A-D                  |
| Has IPv6 but offers no downstream PD     | Stop; do not deploy NAT66                 |
| Has no IPv6                              | Stop or separately design a tunnel broker |

Before Phase B, record the delegated prefix length and whether it remains
stable across lease renewal and CPE reboot. Prefix stability does not change
the token design, but determines how disruptive literal-address consumers
would be.

## Phase A — primary WAN receive and PD

1. In `hosts/yirukou/networking/firewall.nix`, exempt only essential
   primary-WAN ICMPv6 link-local traffic before the raw `fe80::/10` bogon drop.
   Include RA, NS, NA, and required error/PMTU messages. Keep ordinary
   link-local traffic blocked and reject all IPv6 ingress/forwarding on
   fallback `enp6s0`. This must precede reliance on WAN RA or PD.

1. Import `modules/networking/ipv6.nix` on yirukou so both servers use the same
   IPv6-enabled, no-privacy-address, IPv6-before-IPv4 policy.

1. In `hosts/yirukou/networking/sysctl.nix`, explicitly own:

   - `net.ipv6.conf.all.forwarding = 1`

   Let systemd-networkd own per-interface forwarding and RA behavior.
   `IPv6AcceptRA = "yes"` uses networkd's userspace RA client on `enp7s0`;
   do not add kernel `accept_ra` sysctls. `enp6s0` remains IPv6-disabled.

1. In `hosts/yirukou/networking/wans.nix`:

   - primary `enp7s0`: enable DHCPv6 as well as DHCPv4, retain
     `IPv6AcceptRA = "yes"`, request PD with
     `dhcpV6Config.PrefixDelegationHint`, set
     `dhcpV6Config.WithoutRA = "solicit"`, set `dhcpV6Config.UseDNS = false`
     and `ipv6AcceptRAConfig.UseDNS = false`, and retain the local resolver;
   - fallback `enp6s0`: retain `DHCP = "ipv4"` and set
     `IPv6AcceptRA = "no"` and `LinkLocalAddressing = "no"`.

   `dhcpV6Config.PrefixDelegation = true` is not a valid networkd option.
   `PrefixDelegationHint` requests the PD; downstream interfaces consume it
   with `networkConfig.DHCPPrefixDelegation = true`.

1. Apply yirukou and verify `enp7s0` receives a global address, a default route,
   and a delegated prefix. Verify `enp6s0` has no learned IPv6 default route.

```sh
ip -6 address show dev enp7s0
ip -6 route show
networkctl status enp7s0
journalctl -u systemd-networkd
```

No PD means stop at the project gate.

## Phase B — yirukou LAN routing and RA

1. In `hosts/yirukou/networking/bridge.nix`, configure `br0` with:

   - `LinkLocalAddressing = "ipv6"`
   - `IPv6AcceptRA = "no"` (it is a router-facing LAN interface)
   - `IPv6Forwarding = true`
   - `DHCPPrefixDelegation = true`
   - `IPv6SendRA = true`
   - a deterministic `dhcpPrefixDelegationConfig.SubnetId`
   - `dhcpPrefixDelegationConfig.Announce = true`
   - `dhcpPrefixDelegationConfig.Assign = true` and yirukou's `::1` token
   - `dhcpPrefixDelegationConfig.ManageTemporaryAddress = false`
   - `ipv6SendRAConfig.EmitDNS = true` with `DNS = "_link_local"`

   Keep link-local addressing disabled on the bridge member ports; addresses
   belong on `br0`.

1. Apply the same downstream-PD and RA design to VLAN 42 in
   `hosts/yirukou/networking/untrusted.nix`, using a different subnet ID.
   Keep link-local addressing disabled on the VLAN parent `enp2s0`.

1. In `modules/addresses.nix`, record stable interface IDs separately from
   complete addresses. Do not construct a full GUA in Nix from an unknown
   delegated prefix. Replace the RFC 3849 sinkhole placeholders with static
   ULA `fd75:c55f:6d19::24`. `dnsBindHosts` is defined here, not in
   `hosts/yirukou/services.nix`.

1. Bind yirukou AdGuard Home DNS on IPv6 wildcard and link-local as required,
   then enforce exposure by interface in the firewall. Audit both
   `services.adguardhome.host`/`http.address` and `dns.bind_hosts`; they are
   separate listeners and currently use IPv4.

1. Assign `fd75:c55f:6d19::24/128` only to yirukou `br0`, configure both
   AdGuard instances to return it for blocked AAAA queries, and reject it in
   the static nftables sinkhole table. Do not advertise its ULA prefix by RA
   and do not assign it on yifuwuqi.

1. Audit `hosts/yirukou/networking/firewall.nix` for:

   - LAN-to-primary-WAN IPv6 forwarding;
   - established/related return traffic;
   - required ICMPv6 and PMTU discovery;
   - no IPv6 forwarding through `enp6s0`;
   - pre-filter enforcement before NixOS's general ICMPv6 accepts;
   - DNS interception exemptions for Tailscale MagicDNS at
     `100.100.100.100` and `fd7a:115c:a1e0::53`;
   - yifuwuqi's dynamic-prefix IID `::2` DNS exemption scoped to `br0`.

1. Verify one ordinary LAN client receives a GUA, default route, and RDNSS
   automatically. Verify it has no manually assigned address.

1. Verify a VLAN 42 client independently; do not infer VLAN behavior from
   `br0`.

## Phase C — yifuwuqi and DNS

1. In `hosts/yifuwuqi/networking/interfaces/eno1.nix`, enable IPv6 link-local
   addressing and RA. Set `ipv6AcceptRAConfig.Token` to stable `::2` while
   learning the prefix and default route automatically. Set an explicit RA
   route metric so the IPv6 route is unambiguous alongside IPv4 keepalived.
1. Keep IPv6 disabled on yifuwuqi `enp4s0` and `wlp2s0`.
1. In `modules/services/unbound.nix`, set `do-ip6 = "yes"` and listen on both
   `127.0.0.1` and loopback `::1`. Add `::1/128 allow` to `access-control`.
1. In `modules/services/adguardhome.nix`, use IPv6 loopback Unbound endpoints
   before IPv4 loopback using bracketed `[::1]:5335` syntax and set
   `bootstrap_prefer_ipv6 = true`. This preference is meaningful only after
   Unbound listens on `::1`; the current bootstrap target is local Unbound,
   not Quad9.
1. Bind yifuwuqi AdGuard DNS on IPv6 wildcard rather than putting a dynamic
   full GUA in `modules/addresses.nix`. Extend its default-deny firewall only
   for the intended LAN DNS and management paths; keep container isolation and
   unrelated services unchanged.
1. Deploy shared Unbound and AdGuard module changes to yirukou first, verify
   them, then yifuwuqi. Both hosts import these modules, so a shared edit must
   not be treated as a single-host change.
1. Verify both Unbound instances make outbound IPv6 queries. Returning an AAAA
   record alone is insufficient because DNS transport could still be IPv4.

## Phase D — end-to-end and fallback verification

1. Both servers have a global IPv6 address and default route through yirukou.
1. Separate LAN and VLAN 42 clients each receive a GUA, default route, and
   yirukou link-local RDNSS automatically.
1. `ping -6 2620:fe::fe` works from both servers and a LAN client.
1. Both `dig @127.0.0.1 AAAA github.com` and `dig @::1 AAAA github.com` work.
   Unbound statistics or packet capture confirms outbound IPv6 transport.
1. AdGuard Home listens on IPv6 and filter downloads work with IPv6 preferred.
1. A blocked AAAA query returns `fd75:c55f:6d19::24`. Verify ordinary clients
   receive an immediate nftables rejection from yirukou.
1. Native IPv6 has higher address-selection precedence than IPv4 on both
   servers. Test a dual-stack destination, not only an IPv6-only destination.
1. Disable or disconnect primary-WAN IPv6 and verify dual-stack applications
   continue over IPv4. Address selection alone does not guarantee instant
   fallback; applications without Happy Eyeballs may wait for IPv6 failure.
1. Confirm the fallback WAN never acquires a global IPv6 address or IPv6
   default route.
1. Trigger yifuwuqi's IPv4 fallback to `enp4s0` while IPv6 remains on `eno1`.
   Confirm IPv4 and IPv6 take their intended independent paths without
   reverse-path or firewall drops.
1. Evaluate both NixOS configurations before each deployment and add
   IPv6-specific ICMP, AAAA, and transport probes after manual validation.

## Global IPv6/IP6 audit

| Existing setting / alias                   | Final state                                                              |
| ------------------------------------------ | ------------------------------------------------------------------------ |
| yirukou primary WAN RA/DHCPv6-PD           | enabled                                                                  |
| yirukou fallback WAN RA/DHCPv6             | disabled intentionally                                                   |
| yirukou WAN ICMPv6/ND before bogon drop    | essential primary-WAN traffic allowed                                    |
| yirukou `br0` and VLAN 42                  | IPv6 forwarding, delegated `/64`, RA enabled                             |
| bridge member ports / VLAN parent          | link-local disabled intentionally                                        |
| yifuwuqi `eno1`                            | RA plus stable `::2` token enabled                                       |
| yifuwuqi `enp4s0`, `wlp2s0`                | IPv6 disabled intentionally                                              |
| `networking.enableIPv6` / RFC 6724 policy  | enabled on both hosts                                                    |
| temporary/privacy IPv6 addresses           | disabled on both hosts, including delegated LAN/VLAN addresses           |
| Unbound `do-ip6`, loopback `::1`, ACL      | enabled on both hosts                                                    |
| AdGuard `ipv6_disabled`                    | already false                                                            |
| AdGuard DNS bind and `[::1]:5335` upstream | enabled; wildcard exposure firewall-gated                                |
| AdGuard admin `host` / `http.address`      | explicitly reviewed; not implied by DNS bind                             |
| AdGuard A/AAAA rewrites                    | existing internal rewrites remain IPv4 unless designed                   |
| Sinkhole `ip6` / ICMPv6 rules              | static ULA `fd75:c55f:6d19::24`; assigned only on yirukou                |
| `.lan`, `.local`, `.ts`, `.nb` aliases     | existing IPv4 answers retained; AAAA added only with runtime current GUA |
| Kea DHCPv4 / SLAAC / RDNSS                 | DHCPv4 retained; no Kea DHCPv6 server                                    |
| keepalived                                 | IPv4-only intentionally                                                  |
| Tailscale/NetBird LAN route advertisement  | IPv4-only intentionally; overlay IPv6 remains                            |
| qBittorrent VPN `disable_ipv6=1`           | retained intentionally to prevent VPN leaks                              |
| SSH `listenWildcardIPv6 = null`            | retained; no broad IPv6 SSH exposure                                     |
| yifuwuqi firewall `ip` rules               | retained; explicit `ip6` additions only where required                   |
| nginx proxy/backend and Valkey transport   | retained on static IPv4                                                  |
| Podman `ipv6_enabled = true`               | already enabled; no container-GUA rollout implied                        |
| Avahi `nssmdns6 = true`                    | already enabled                                                          |
| `AF_INET6` service sandbox allowances      | already present where required                                           |
| ICMP/DNS/HTTP monitoring probes            | existing IPv4 probes retained; dedicated IPv6 probes added               |

## Failure and failover behavior

keepalived remains IPv4-only. IPv6 exists only through primary `enp7s0`; there
is no IPv6 route through fallback `enp6s0`. During IPv4 WAN failover, IPv6 must
be withdrawn from LAN clients promptly and dual-stack applications fall back
to IPv4. Verify RA router/prefix lifetimes and withdrawal behavior rather than
assuming address precedence alone handles the transition.

yifuwuqi can simultaneously use IPv4 through fallback `enp4s0` and IPv6
through yirukou on `eno1`. This is intentional independent dual-stack routing,
but must be tested for application behavior, reverse-path filtering, and
firewall asymmetry. Loss of primary IPv6 must not remove or rewrite existing
static IPv4 addresses.

## Rollout order

Primary CPE/ISP check → Phase A primary WAN → Phase B yirukou LAN/VLAN →
Phase C yifuwuqi/DNS → Phase D IPv6 preference and IPv4 fallback. Apply and
verify each phase before continuing.

## Documentation follow-up

After implementation, update current-state documentation rather than marking
future behavior as already deployed:

- `docs/src/networking/yirukou.md`
- `docs/src/networking/sysctl-firewall.md`
- `docs/src/hosts/yirukou.md`
- `docs/src/hosts/yifuwuqi.md`
- `docs/src/services/dns-and-proxy.md`
- `docs/src/services/monitoring.md`

Keep IPv4-only components documented as intentional, not as incomplete IPv6
conversion.
