# yirukou Router & Edge Networking

`yirukou` is the network authority for the homelab LAN. It owns routing, firewalling, NAT, DHCP, DNS reachability, reverse proxy ingress, and the Tailscale subnet route for the main LAN.

______________________________________________________________________

## 1. Address Plan

| Network          | Interface    | Address                                      | Purpose                                   |
| ---------------- | ------------ | -------------------------------------------- | ----------------------------------------- |
| **LAN**          | `br0`        | `10.42.0.1/24`, delegated `/64` token `::1`  | Trusted wired LAN and default gateway.    |
| **Untrusted**    | `enp2s0.42`  | `10.42.42.1/24`, delegated `/64` token `::1` | VLAN 42 for untrusted / guest clients.    |
| **Tailscale**    | `tailscale0` | `100.69.0.1/32`                              | Tailnet access, subnet router, exit node. |
| **Sinkhole**     | `br0` alias  | `10.42.0.24/24`                              | Retained IPv4 sinkhole address.           |
| **Sinkhole v6**  | `br0` alias  | `fd75:c55f:6d19::24/128`                     | Static ULA IPv6 sinkhole address.         |
| **WAN primary**  | `enp7s0`     | DHCPv4 plus RA/DHCPv6-PD                     | Preferred uplink (metric 100).            |
| **WAN fallback** | `enp6s0`     | DHCPv4 only (metric 200)                     | Backup IPv4 uplink.                       |

The canonical address registry is `modules/addresses.nix`.

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
- IPv6 forwarding, delegated-prefix assignment, and RA are enabled on both
  routed LAN interfaces. Subnet IDs are `0` and `1`; delegated addresses use
  stable `::1` tokens and do not create temporary addresses.
- Clients use SLAAC and yirukou's link-local RDNSS address; there is no DHCPv6
  server.
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
Only `enp7s0` accepts RA and runs DHCPv6 with a `/56` PD hint. DHCPv6
solicitation does not depend on RA M/O flags. `enp6s0` rejects RA, disables
IPv6 link-local addressing, and has no IPv6 failover role.

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

- **Bogon Drop**: Named sets `wan_bogon_v4` / `wan_bogon_v6` drop spoofed
  sources in raw prerouting, `fe80::/10` included. Essential link-local ICMPv6
  (RA, NS, NA, errors) and DHCPv6 replies jump through `wan_ll_ok` only on
  `enp7s0`.
- **Fallback isolation**: IPv6 ingress and forwarding through `enp6s0` are
  dropped.
- **Inbound IPv6**: A pre-filter chain drops unsolicited WAN-to-internal IPv6;
  established/related replies and ICMPv6 errors return through the NixOS
  firewall's conntrack vmap.
- **Outbound NAT**: NAT44 remains enabled; there is no NAT66.
- **DNS intercept**: TCP/UDP 53 from LAN, VLAN 42, and Tailscale is redirected
  to yirukou AdGuard Home. Exceptions: queries already aimed at AGH IPv4
  binds, local addresses, MagicDNS (`100.100.100.100` and
  `fd7a:115c:a1e0::53`), and yifuwuqi Unbound (`10.42.0.2` / IID `::2` on
  `br0`). Off-net TCP/UDP 853 is dropped. DoH on 443 is not enforced. AGH DDR
  (`handle_ddr`) advertises `dns.fufu.land` DoH on `:3443` and DoQ on `:853`;
  DoT is not in the SVCB set (cert has no IP SANs). There is no DNR or Kea
  DHCPv6.
- **Sinkhole Drop Table**: Statically rejects IPv4 `10.42.0.24` and IPv6
  `fd75:c55f:6d19::24`; no runtime prefix derivation is required.

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
- `modules/addresses.nix`
