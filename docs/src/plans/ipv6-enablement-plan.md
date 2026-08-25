# IPv6 Enablement Plan (yirukou + yifuwuqi)

Goal: enable native IPv6 through yirukou's primary WAN and on the LANs it
serves. IPv6 is preferred when usable; IPv4 remains available as fallback.
The fallback WAN and keepalived remain IPv4-only.

## Verified repository state

1. Neither WAN had a global IPv6 address or IPv6 default route when last
   checked. Only the primary WAN, `enp7s0` through CPE `192.168.1.1`, is in
   scope for IPv6. `enp6s0` stays IPv4-only.
1. yirukou already has `net.ipv6.conf.all.forwarding = 1` at runtime because
   the NixOS Tailscale module sets it when `useRoutingFeatures` is `server` or
   `both`. `yi.tailscale.routingMode = "both"` selects that mode. Forwarding
   changes a Linux interface's default `accept_ra` behavior to `0`, so the
   primary WAN needs `accept_ra = 2`.
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

## Address and routing design

- The ISP delegates a prefix to yirukou over `enp7s0` using DHCPv6-PD.
- systemd-networkd automatically assigns one `/64` to `br0` and one `/64` to
  VLAN 42 and advertises them using RA.
- Ordinary clients receive addresses, routes, and DNS information
  automatically through SLAAC/RDNSS.
- Only server identities have fixed interface identifiers: yirukou `::1`,
  yifuwuqi `::2`, and the sinkhole service address `::24`. Prefer networkd
  `Token=`/`Assign=` so the delegated prefix remains automatic.
- If the ISP rotates the PD and a consumer requires literal full addresses
  (notably RDNSS or an application bind), use a generated RFC 4193 ULA prefix
  for stable internal server/DNS addresses while retaining automatic GUA for
  internet access. Do not hard-code a changing ISP prefix in the repository.
- `fc00::/7` is a private ULA range. ULA is suitable for stable internal
  addressing but does not provide IPv6 internet access by itself.
- No NAT66.

| Segment             | Delegated prefix | Router        | Server         | Sinkhole        | Clients |
| ------------------- | ---------------- | ------------- | -------------- | --------------- | ------- |
| LAN (`br0`)         | first `/64`      | yirukou `::1` | yifuwuqi `::2` | `::24`          | SLAAC   |
| Untrusted (VLAN 42) | second `/64`     | yirukou `::1` | —              | optional `::24` | SLAAC   |
| Spare               | remaining `/64`s | —             | —              | —               | —       |

The PD must contain at least two `/64`s for both current segments. A single
upstream `/64` cannot be routed onto both LANs without an undesirable
workaround.

### Project gate

Check only the primary CPE (`192.168.1.1`) and ISP:

| Primary CPE/ISP result                   | Action                                    |
| ---------------------------------------- | ----------------------------------------- |
| Delegates at least two `/64`s to yirukou | Continue with Phases A-D                  |
| Has IPv6 but offers no downstream PD     | Stop; do not deploy NAT66                 |
| Has no IPv6                              | Stop or separately design a tunnel broker |

## Phase A — primary WAN receive and PD

1. Import `modules/networking/ipv6.nix` on yirukou so both servers use the same
   IPv6-enabled, no-privacy-address, IPv6-before-IPv4 policy.

1. In `hosts/yirukou/networking/sysctl.nix`, explicitly own:

   - `net.ipv6.conf.all.forwarding = 1`
   - `net.ipv6.conf.default.forwarding = 1`
   - `net.ipv6.conf.enp7s0.accept_ra = 2`

   Do not set `accept_ra = 2` on `enp6s0`.

1. In `hosts/yirukou/networking/wans.nix`:

   - primary `enp7s0`: enable DHCPv6 as well as DHCPv4, retain
     `IPv6AcceptRA = "yes"`, request PD with
     `dhcpV6Config.PrefixDelegationHint`, and prevent RA/DHCPv6 DNS from
     replacing the local resolver;
   - fallback `enp6s0`: retain `DHCP = "ipv4"` and set
     `IPv6AcceptRA = "no"`.

   `dhcpV6Config.PrefixDelegation = true` is not a valid networkd option.
   `PrefixDelegationHint` requests the PD; downstream interfaces consume it
   with `networkConfig.DHCPPrefixDelegation = true`.

1. In `hosts/yirukou/networking/firewall.nix`, exempt essential primary-WAN
   ICMPv6 link-local traffic (RA, NS, NA, and required error messages) before
   the raw `fe80::/10` bogon drop. Keep link-local blocked for ordinary
   primary-WAN traffic and keep all IPv6 blocked on the fallback WAN.

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
   - a deterministic subnet ID and yirukou's `::1` token
   - RDNSS for yirukou and yifuwuqi

   Keep link-local addressing disabled on the bridge member ports; addresses
   belong on `br0`.

1. Apply the same downstream-PD and RA design to VLAN 42 in
   `hosts/yirukou/networking/untrusted.nix`, using a different subnet ID.
   Keep link-local addressing disabled on the VLAN parent `enp2s0`.

1. In `modules/addresses.nix`, replace the RFC 3849 sinkhole placeholders and
   record the stable server/service addresses. `dnsBindHosts` is defined here,
   not in `hosts/yirukou/services.nix`.

1. Bind yirukou AdGuard Home on IPv6. If the GUA prefix is dynamic, bind the
   IPv6 wildcard and enforce exposure with the firewall instead of embedding
   the changing GUA in `bind_hosts`.

1. Audit `hosts/yirukou/networking/firewall.nix` for:

   - LAN-to-primary-WAN IPv6 forwarding;
   - established/related return traffic;
   - required ICMPv6 and PMTU discovery;
   - no IPv6 forwarding through `enp6s0`.

1. Verify one ordinary LAN client receives a GUA, default route, and RDNSS
   automatically. Verify it has no manually assigned address.

## Phase C — yifuwuqi and DNS

1. In `hosts/yifuwuqi/networking/interfaces/eno1.nix`, enable IPv6 link-local
   addressing and RA. Use a stable `::2` token for its server identity while
   learning the prefix and default route automatically.
1. Keep IPv6 disabled on yifuwuqi `enp4s0` and `wlp2s0`.
1. In `modules/services/unbound.nix`, set `do-ip6 = "yes"` and listen on both
   `127.0.0.1` and `::1`.
1. In `modules/services/adguardhome.nix`, use IPv6 loopback Unbound endpoints
   before IPv4 loopback and set `bootstrap_prefer_ipv6 = true`. This preference
   is meaningful only after Unbound listens on `::1`; the current
   `bootstrap_dns = [ "127.0.0.1:5335" ]` does not use Quad9 directly.
1. In `modules/addresses.nix`, add yifuwuqi's stable IPv6 server address to its
   AdGuard Home bind list, or use an IPv6 wildcard when the PD is dynamic and
   rely on the firewall.
1. Verify both Unbound instances make outbound IPv6 queries. Returning an AAAA
   record alone is insufficient because DNS transport could still be IPv4.

## Phase D — end-to-end and fallback verification

1. Both servers have a global IPv6 address and default route through yirukou.
1. LAN and VLAN 42 clients receive IPv6 automatically.
1. `ping -6 2620:fe::fe` works from both servers and a LAN client.
1. `dig @127.0.0.1 AAAA github.com` works, and Unbound statistics or packet
   capture confirms outbound IPv6 transport.
1. AdGuard Home listens on IPv6 and filter downloads work with IPv6 preferred.
1. Native IPv6 has higher address-selection precedence than IPv4 on both
   servers. Test a dual-stack destination, not only an IPv6-only destination.
1. Disable or disconnect primary-WAN IPv6 and verify dual-stack applications
   continue over IPv4. Address selection alone does not guarantee instant
   fallback; applications without Happy Eyeballs may wait for IPv6 failure.
1. Confirm the fallback WAN never acquires a global IPv6 address or IPv6
   default route.

## Global IPv6/IP6 audit

| Existing setting                           | Final state                                           |
| ------------------------------------------ | ----------------------------------------------------- |
| yirukou primary WAN RA/DHCPv6              | enabled                                               |
| yirukou fallback WAN RA/DHCPv6             | disabled intentionally                                |
| yirukou `br0` and VLAN 42                  | IPv6 forwarding, PD, RA enabled                       |
| yirukou bridge member ports / VLAN parent  | link-local disabled intentionally                     |
| yifuwuqi `eno1`                            | IPv6 RA plus stable server token enabled              |
| yifuwuqi `enp4s0`, `wlp2s0`                | disabled intentionally                                |
| Unbound `do-ip6` and `::1` listener        | enabled on both hosts                                 |
| AdGuard `ipv6_disabled`                    | already false                                         |
| AdGuard `bootstrap_prefer_ipv6`            | enabled                                               |
| Sinkhole `ip6` rules                       | enabled with non-documentation addresses              |
| `networking.enableIPv6` / IPv6 precedence  | enabled on both hosts                                 |
| keepalived                                 | IPv4-only intentionally                               |
| Tailscale LAN route advertisement          | IPv4-only intentionally; Tailscale's own IPv6 remains |
| qBittorrent VPN namespace `disable_ipv6=1` | disabled intentionally to prevent VPN leaks           |
| SSH `listenWildcardIPv6 = null`            | unchanged; do not expose SSH on all IPv6 addresses    |
| Podman `ipv6_enabled = true`               | already enabled                                       |
| Avahi `nssmdns6 = true`                    | already enabled                                       |

## Failure and failover behavior

keepalived remains IPv4-only. IPv6 exists only through primary `enp7s0`; there
is no IPv6 route through fallback `enp6s0`. During IPv4 WAN failover, IPv6 must
be withdrawn from LAN clients promptly and dual-stack applications fall back
to IPv4. Verify RA router/prefix lifetimes and withdrawal behavior rather than
assuming address precedence alone handles the transition.

## Rollout order

Primary CPE/ISP check → Phase A primary WAN → Phase B yirukou LAN/VLAN →
Phase C yifuwuqi/DNS → Phase D IPv6 preference and IPv4 fallback. Apply and
verify each phase before continuing.
