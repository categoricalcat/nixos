# yirukou Router & Edge Networking

`yirukou` is the network authority for the homelab LAN. It owns routing, firewalling, NAT, DHCP, DNS reachability, reverse proxy ingress, and the Tailscale subnet route for the main LAN.

______________________________________________________________________

## 1. Address Plan

| Network          | Interface    | Address                                   | Purpose                                   |
| ---------------- | ------------ | ----------------------------------------- | ----------------------------------------- |
| **LAN**          | `br0`        | `10.42.0.1/24`, `fd75:c55f:6d19:1::1/64`  | Trusted wired LAN and default gateway.    |
| **Untrusted**    | `enp2s0.42`  | `10.42.42.1/24`, `fd75:c55f:6d19:2::1/64` | VLAN 42 for untrusted / guest clients.    |
| **Tailscale**    | `tailscale0` | `100.69.0.1/32`                           | Tailnet access, subnet router, exit node. |
| **Sinkhole**     | `br0` alias  | `10.42.0.24/24`                           | Retained IPv4 sinkhole address.           |
| **Sinkhole v6**  | `br0` alias  | `fd75:c55f:6d19::24/128`                  | Static ULA IPv6 sinkhole address.         |
| **WAN primary**  | `enp7s0`     | DHCPv4 only, IPv6 disabled                | Preferred uplink (metric 100).            |
| **WAN fallback** | `enp6s0`     | DHCPv4 only, IPv6 disabled (metric 200)   | Backup IPv4 uplink.                       |

The canonical address registry is `modules/addresses.nix`.

IPv6 is LAN-only and permanent. The ULA `fd75:c55f:6d19::/48` is locally
assigned, so nothing depends on the ISP: there is no prefix delegation, no
global address on any interface, and no IPv6 default route or internet egress
anywhere in the fabric. IPv4 carries all external traffic. This is intentional,
not an unfinished rollout. Why GUA from the CPE is unused, and what would have
to change to use it, is in [IPv6 ULA vs GUA](ipv6-ula-gua.md).

______________________________________________________________________

## 2. Layer 2 Bridge & VLAN Layout

`br0` is a `systemd-networkd` software bridge. The trusted LAN bridge members are physical ports `enp5s0`, `enp4s0`, and `enp3s0`. Physical port `enp2s0` is dedicated to 802.1Q tagged VLAN 42:

```text
br0 (10.42.0.1/24)
├── enp5s0
├── enp4s0
└── enp3s0

enp2s0 (VLAN parent, no IP)
└── enp2s0.42 (10.42.42.1/24 untrusted network)
```

- IPv4 forwarding is enabled on `br0` and `enp2s0.42`.
- IPv6 forwarding and RA are enabled on both routed LAN interfaces, each with a
  statically configured ULA `/64`: `fd75:c55f:6d19:1::1/64` on `br0` and
  `fd75:c55f:6d19:2::1/64` on `enp2s0.42`. Neither accepts RA.
- RA carries the on-link prefix and RDNSS with `RouterLifetimeSec = 0`, so
  clients autoconfigure an address and a DNS server but install no IPv6 default
  route. RDNSS advertises the segment's static ULA, not a link-local address.
- Clients use SLAAC; there is no DHCPv6 server. Temporary/privacy addresses are
  disabled globally through networkd `IPv6PrivacyExtensions = false`.
- Sinkhole IP `10.42.0.24/24` is bound directly to `br0`.
- Sinkhole ULA `fd75:c55f:6d19::24/128` is bound to `br0` but its prefix is not
  advertised as on-link by RA.

______________________________________________________________________

## 3. High-Performance DHCP (Kea)

DHCP is provided by Kea (`services.kea.dhcp4`) rather than `systemd-networkd`:

| Scope                 | Subnet          | Pool                          | Router       | DNS Servers              |
| --------------------- | --------------- | ----------------------------- | ------------ | ------------------------ |
| **Trusted LAN**       | `10.42.0.0/24`  | `10.42.0.100 - 10.42.0.250`   | `10.42.0.1`  | `10.42.0.1`, `10.42.0.2` |
| **Untrusted VLAN 42** | `10.42.42.0/24` | `10.42.42.100 - 10.42.42.250` | `10.42.42.1` | `10.42.42.1`             |

______________________________________________________________________

## 4. WAN Failover & Keepalived

Both WAN interfaces acquire IPv4 through DHCPv4 with `UseRoutes = false`;
IPv4 default routing remains owned by `modules/networking/gateway-failover.nix`.
Both set `DHCP = "ipv4"`, `IPv6AcceptRA = "no"`, and
`LinkLocalAddressing = "no"`, so neither uplink carries IPv6 at all. Failover
is IPv4-only, and LAN IPv6 is unaffected by uplink transitions because it
depends on no uplink.

- **Keepalived VRRP**: Monitored by `check_enp7s0` running `wan-check`.
- **Target Probing**: `wan-check` tests internet targets (`216.239.35.0`, `200.160.0.8`) via explicit `/32` host routes through the primary gateway.
- **Failover Action**: On transition to `BACKUP` or `FAULT`, `wan-notify` switches the default route to the fallback WAN.
- **Conntrack Flush**: State is saved in `/run/gateway-failover-active-gw`. `conntrack -F` executes strictly when the active gateway changes.

______________________________________________________________________

## 5. Tailscale Subnet Router & Exit Node

`yirukou` runs `modules/services/tailscale.nix` in `both` mode:

- Advertises LAN subnet `10.42.0.0/24`.
- Advertises itself as a full exit node (`--advertise-exit-node`).
- Accepts Tailscale DNS.
- Trusts `tailscale0` in the host firewall.
- **`tailscale-udp-gro.service`**: Systemd oneshot enabling UDP Generic Receive Offload forwarding across all interfaces on boot.

> [!NOTE]
> `yixiaoqing` (laptop) is configured to use `yirukou` (`100.69.0.1`) as its exit node when roaming. `yifuwuqi` operates as a server without an exit node (`exitNodeHost = null`).

______________________________________________________________________

## 6. Firewall, NAT & Bogon Filtering

- **Bogon Drop**: Named set `wan_bogon_v4` drops spoofed IPv4 sources in raw
  prerouting. There is no active `wan_bogon_v6` set: IPv6 is dropped on both
  WANs outright, so a bogon classifier would never run. Restore IPv6 bogon
  filtering together with WAN GUA; see [IPv6 ULA vs GUA](ipv6-ula-gua.md).
- **WAN IPv6 drop**: IPv6 is dropped unconditionally on both WAN interfaces in
  raw prerouting and in the `yirukou-edge` input, output, and forward chains.
  There is no WAN RA, ND, or DHCPv6 handling and no IPv6 egress.
- **Segment isolation**: VLAN 42 and the LAN are isolated from each other for
  `ip6` (`fd75:c55f:6d19:1::/64` ↔ `fd75:c55f:6d19:2::/64`) as they are for
  IPv4.
- **Outbound NAT**: NAT44 remains enabled; there is no NAT66 or NPTv6.
- **DNS intercept**: TCP/UDP 53 from LAN, VLAN 42, and Tailscale is redirected
  to yirukou AdGuard Home. Exceptions: queries already aimed at AGH IPv4 or
  ULA binds, local addresses, MagicDNS (`100.100.100.100` and
  `fd7a:115c:a1e0::53`), and yifuwuqi Unbound (`10.42.0.2` /
  `fd75:c55f:6d19:1::2` on `br0`). Off-net TCP/UDP 853 is dropped. DoH on 443
  is not enforced. AGH DDR (`handle_ddr`) advertises `dns.fufu.land` DoH on
  `:3443` and DoQ on `:853`; DoT is not in the SVCB set (cert has no IP SANs).
  There is no DNR or Kea DHCPv6.
- **Sinkhole Drop Table**: Statically rejects IPv4 `10.42.0.24` and IPv6
  `fd75:c55f:6d19::24`; no runtime prefix derivation is required. The sinkhole
  `/64` is never advertised, so for clients without an IPv6 default route a
  blocked AAAA answer is simply unreachable and fails locally; the nft rules
  matter only for hosts that can route to it, which is yirukou itself.

______________________________________________________________________

## 7. Key Source Files

- `hosts/yirukou/networking.nix`
- `hosts/yirukou/networking/bridge.nix`
- `hosts/yirukou/networking/untrusted.nix`
- `hosts/yirukou/networking/dhcp.nix`
- `hosts/yirukou/networking/wans.nix`
- `hosts/yirukou/networking/firewall.nix`
- `hosts/yirukou/networking/sysctl.nix`
- `modules/networking/gateway-failover.nix`
- `modules/networking/sinkhole.nix`
- `modules/networking/ipv6.nix`
- `modules/addresses.nix`
