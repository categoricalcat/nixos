# yirukou Router

`yirukou` is the network authority for the homelab LAN. It owns routing,
firewalling, NAT, DHCP, DNS reachability, reverse proxy ingress, and the
Tailscale subnet route for the main LAN.

## Address Plan

| Network | Interface | Address | Purpose |
| --- | --- | --- | --- |
| LAN | `br0` | `10.42.0.1/24` | Trusted wired LAN and default gateway. |
| Untrusted | `enp2s0.42` | `10.42.42.1/24` | VLAN 42 for untrusted clients. |
| Tailscale | `tailscale0` | `100.69.0.1/32` | Tailnet access, subnet router, exit node. |
| Sinkhole | `br0` alias | `10.42.0.24/24` | AdGuard blocking address. |
| WAN primary | `enp7s0` | DHCPv4 | Preferred uplink. |
| WAN fallback | `enp6s0` | DHCPv4 | Backup uplink. |

The canonical address registry is `modules/addresses.nix`.

## Layer 2 Layout

`br0` is a systemd-networkd bridge. The trusted LAN bridge members are every
configured LAN port except the untrusted VLAN parent:

```text
br0
|-- enp5s0
|-- enp4s0
|-- enp3s0
`-- enp2s0 untagged

enp2s0.42
`-- VLAN 42 untrusted network
```

Current implementation notes:

- `enp2s0` carries untagged trusted traffic into `br0`.
- `enp2s0.42` is a routed VLAN interface and is not a bridge member.
- IPv4 forwarding is enabled on `br0` and `enp2s0.42`.
- IPv6 forwarding is intentionally not designed yet.

## DHCP

DHCP is provided by Kea, not by systemd-networkd.

| Scope | Subnet | Pool | Router |
| --- | --- | --- | --- |
| Trusted LAN | `10.42.0.0/24` | `10.42.0.100 - 10.42.0.250` | `10.42.0.1` |
| Untrusted VLAN 42 | `10.42.42.0/24` | `10.42.42.100 - 10.42.42.250` | `10.42.42.1` |

Both scopes advertise the LAN DNS servers from the address registry:

- `10.42.0.1`
- `10.42.0.2`

## WAN Failover

Both WAN interfaces use DHCPv4 through systemd-networkd, but `UseRoutes = false`
keeps networkd from installing default routes directly. The
`modules/networking/gateway-failover.nix` module owns default-route selection.

Failover behavior:

- `keepalived` probes `1.1.1.1` through the primary interface.
- `MASTER` installs the primary default route.
- `FAULT`, `BACKUP`, or `STOP` installs the fallback default route.
- Conntrack is flushed on route transitions so NAT sessions rebuild through the
  active uplink.

## Tailscale

`yirukou` runs the shared Tailscale module in `both` mode:

- advertises `10.42.0.0/24`
- advertises itself as an exit node
- accepts Tailscale DNS
- trusts `tailscale0` in the firewall

`yifuwuqi` uses `yirukou` as its exit node.

## DNS And Proxying

AdGuard Home is enabled on `yirukou` and binds to `0.0.0.0`. Plain DNS is
reachable from internal interfaces through the firewall. TLS-enabled DNS is
available when the host has the `fufu.land` ACME certificate.

`nginx` on `yirukou` terminates the wildcard `fufu.land` certificate and proxies
selected services, including:

- `adguard.fufu.land` to local AdGuard Home
- `dns.fufu.land` to local AdGuard DoH
- `netdata.fufu.land` to Netdata parent mode on `yifuwuqi`
- `search.fufu.land`, `prtnr.fufu.land`, and `agent.fufu.land` to `yifuwuqi`

## Source Files

- `modules/addresses.nix`
- `hosts/yirukou/networking.nix`
- `hosts/yirukou/networking/bridge.nix`
- `hosts/yirukou/networking/untrusted.nix`
- `hosts/yirukou/networking/dhcp.nix`
- `hosts/yirukou/networking/wans.nix`
- `modules/networking/gateway-failover.nix`
- `hosts/yirukou/services.nix`
- `modules/services/adguardhome.nix`
- `modules/services/nginx-proxy.nix`
