# yirukou Router & Edge Networking

`yirukou` is the network authority for the homelab LAN. It owns routing, firewalling, NAT, DHCP, DNS reachability, reverse proxy ingress, and the Tailscale subnet route for the main LAN.

______________________________________________________________________

## 1. Address Plan

| Network             | Interface    | Address             | Purpose                                   |
| ------------------- | ------------ | ------------------- | ----------------------------------------- |
| **LAN**             | `br0`        | `10.42.0.1/24`      | Trusted wired LAN and default gateway.    |
| **Untrusted**       | `enp2s0.42`  | `10.42.42.1/24`     | VLAN 42 for untrusted / guest clients.    |
| **Tailscale**       | `tailscale0` | `100.69.0.1/32`     | Tailnet access, subnet router, exit node. |
| **Sinkhole**        | `br0` alias  | `10.42.0.24/24`     | AdGuard blocking address (IPv4).          |
| **Sinkhole (IPv6)** | `br0` alias  | `2001:db8::2`       | AdGuard blocking address (IPv6).          |
| **WAN primary**     | `enp7s0`     | DHCPv4 (metric 100) | Preferred uplink (`UseRoutes = false`).   |
| **WAN fallback**    | `enp6s0`     | DHCPv4 (metric 200) | Backup uplink (`UseRoutes = false`).      |

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
- Sinkhole IP `10.42.0.24/24` is bound directly to `br0`.

______________________________________________________________________

## 3. High-Performance DHCP (Kea)

DHCP is provided by Kea (`services.kea.dhcp4`) rather than `systemd-networkd`:

| Scope                 | Subnet          | Pool                          | Router       | DNS Servers              |
| --------------------- | --------------- | ----------------------------- | ------------ | ------------------------ |
| **Trusted LAN**       | `10.42.0.0/24`  | `10.42.0.100 - 10.42.0.250`   | `10.42.0.1`  | `10.42.0.1`, `10.42.0.2` |
| **Untrusted VLAN 42** | `10.42.42.0/24` | `10.42.42.100 - 10.42.42.250` | `10.42.42.1` | `10.42.42.1`             |

______________________________________________________________________

## 4. WAN Failover & Keepalived

Both WAN interfaces (`enp7s0` and `enp6s0`) acquire IP addresses via DHCPv4, but `UseRoutes = false` prevents `systemd-networkd` from creating default routes. Default routing is owned by `modules/networking/gateway-failover.nix`:

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

- **Bogon Drop**: Drops 14 IPv4 bogon subnets and 11 IPv6 bogon subnets entering WAN interfaces in raw prerouting.
- **Outbound NAT**: Postrouting masquerading for LAN (`br0`), VLAN 42 (`enp2s0.42`), and Tailscale (`tailscale0`) across active WAN interfaces.
- **Sinkhole Drop Table**: Drops traffic targeting `10.42.0.24` and `2001:db8::2` with TCP reset and ICMP unreachable.

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
