# Host Profile: yirukou (Edge Router & Gateway)

`yirukou` is the primary perimeter authority, default gateway, and reverse proxy for the homelab infrastructure.

______________________________________________________________________

## 1. System & Hardware Specifications

| Component               | Specification                                                                                                                       |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| **Role**                | Perimeter Router, Firewall, DHCP, Reverse Proxy, Primary DNS                                                                        |
| **Architecture**        | `x86_64-linux` (Intel Multi-NIC Platform)                                                                                           |
| **Kernel & Boot**       | Standard kernel with `modules/boot-common.nix`, systemd-boot                                                                        |
| **Filesystems**         | Ext4 root (`685d4cb2-aba3-44d5-b9ba-20a9692ff385`), dedicated Swap partition (`29757075-8a2d-4171-af0f-1027608f9641`), VFAT `/boot` |
| **Power Profile**       | Headless server mode, power management sleep states disabled                                                                        |
| **Secrets Integration** | Sops-nix with host ED25519 SSH key (`/persist/keys/ssh/ssh_host_ed25519_key`)                                                       |

______________________________________________________________________

## 2. Network Topology & Interfaces

```text
                                  ┌────────────────────────┐
                                  │      Internet Uplinks  │
                                  └────┬──────────────┬────┘
           Primary WAN (enp7s0, metric 100)    │      │ Fallback WAN (enp6s0, metric 200)
                                       ▼      ▼
                        ┌──────────────────────────────────────┐
                        │      Keepalived Gateway Failover     │
                        │    (wan-check probe + wan-notify)    │
                        └──────────────────┬───────────────────┘
                                           │
                        ┌──────────────────▼───────────────────┐
                        │               yirukou                │
                        │   ┌──────────────────────────────┐   │
                        │   │ Bridge br0 (10.42.0.1/24)    │   │
                        │   │ ├── enp5s0                   │   │
                        │   │ ├── enp4s0                   │   │
                        │   │ └── enp3s0                   │   │
                        │   └──────────────────────────────┘   │
                        │   ┌──────────────────────────────┐   │
                        │   │ VLAN 42 (enp2s0.42)          │   │
                        │   │ ├── 10.42.42.1/24            │   │
                        │   │ └── fd75:c55f:6d19:2::1/64  │   │
                        │   └──────────────────────────────┘   │
                        │   ┌──────────────────────────────┐   │
                        │   │ Tailscale (100.69.0.1/32)    │   │
                        │   │ └── Subnet Router + Exit Node│   │
                        │   └──────────────────────────────┘   │
                        └──────────────────────────────────────┘
```

### Interface Assignments

| Interface    | Type        | Address / Subnet                          | Role                                                                     |
| ------------ | ----------- | ----------------------------------------- | ------------------------------------------------------------------------ |
| `enp7s0`     | Physical    | Dynamic DHCPv4, IPv6 disabled             | Primary WAN uplink (route metric 100)                                    |
| `enp6s0`     | Physical    | Dynamic DHCPv4, IPv6 disabled             | IPv4-only fallback uplink (route metric 200)                             |
| `br0`        | Bridge      | `10.42.0.1/24`, `fd75:c55f:6d19:1::1/64`  | Trusted LAN bridge enslaving physical ports `enp5s0`, `enp4s0`, `enp3s0` |
| `enp2s0.42`  | 802.1Q VLAN | `10.42.42.1/24`, `fd75:c55f:6d19:2::1/64` | Untrusted / Guest VLAN 42 on parent port `enp2s0`                        |
| `tailscale0` | Tunnel      | `100.69.0.1/32`                           | Tailscale mesh interface (`both` mode: subnet router + exit node)        |

Both WANs are IPv4-only (`DHCP = "ipv4"`, `IPv6AcceptRA = "no"`,
`LinkLocalAddressing = "no"`). IPv6 exists only on the LAN segments as a static
ULA out of `fd75:c55f:6d19::/48`, advertised by RA with `RouterLifetimeSec = 0`
plus RDNSS, so clients get an address and a resolver but no IPv6 default route.
There is no prefix delegation, no global IPv6 address, and no IPv6 internet
egress by design; privacy/temporary addresses are disabled. See
[IPv6 ULA vs GUA](../networking/ipv6-ula-gua.md).

______________________________________________________________________

## 3. Core Network Services

### 3.1 Gateway Failover (Keepalived)

- Configured via `modules/networking/gateway-failover.nix` and `hosts/yirukou/networking/wans.nix`.
- Both WAN interfaces request DHCP leases but have `UseRoutes = false` to prevent `systemd-networkd` from managing default routing.
- **`wan-check`**: Periodically pings targets (`216.239.35.0`, `200.160.0.8`) using dedicated `/32` host routes bound through the primary gateway.
- **`wan-notify`**: On state transitions (`MASTER` $\\leftrightarrow$ `BACKUP`/`FAULT`), dynamically replaces the system default route (`ip route replace default via <GW> dev <IFACE>`).
- **Conntrack Management**: State is recorded in `/run/gateway-failover-active-gw`. `conntrack -F` is executed strictly when the active gateway interface actually changes.

### 3.2 Tailscale UDP Generic Receive Offload (GRO)

- `tailscale-udp-gro.service`: Runs on boot to enable `rx-udp-gro-forwarding on` and `rx-gro-list off` across all WAN, LAN bridge, and physical interfaces (`enp7s0`, `enp6s0`, `br0`, `enp5s0`, `enp4s0`, `enp3s0`, `enp2s0`) for high-throughput WireGuard/Tailscale processing.

### 3.3 Kea DHCPv4 Server

- High-performance DHCP service (`services.kea.dhcp4`) serving both segments from `/var/lib/kea/dhcp4.leases`:
  - **Trusted LAN (`10.42.0.0/24`)**: Pool `10.42.0.100` – `10.42.0.250`, router `10.42.0.1`, DNS servers `10.42.0.1` and `10.42.0.2`.
  - **Untrusted VLAN (`10.42.42.0/24`)**: Pool `10.42.42.100` – `10.42.42.250`, router `10.42.42.1`, DNS server `10.42.42.1`.

______________________________________________________________________

## 4. Firewall, NAT & Kernel Hardening

### 4.1 Nftables Packet Filtering

- **Allowed Ingress Ports**:
  - `br0` (LAN): TCP `53` (DNS), `80` (HTTP), `443` (HTTPS), `853` (DoT/DoQ), `3443` (AGH DoH), `24212` (SSH); UDP `53` (DNS), `67` (DHCP), `853` (DoT/DoQ).
  - `enp2s0.42` (Untrusted): TCP `53`, `80`, `443`, `853`, `3443`; UDP `53`, `67`, `853` (SSH is blocked).
  - `tailscale0`: TCP `24212` (SSH).
  - WANs (`enp7s0`, `enp6s0`): UDP `51820` (Tailscale / WireGuard).
- **Bogon Filtering**: Raw prerouting chain drops 14 IPv4 bogon subnets (`0.0.0.0/8`, `10.0.0.0/8`, `100.64.0.0/10`, `127.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, etc.) entering WAN interfaces. No IPv6 bogon set is needed.
- **Forwarding & NAT**:
  - Outbound NAT44 masquerading on WANs for LAN, VLAN 42, and Tailscale traffic; no NAT66.
  - Forwarding enabled between Tailscale and LAN subnet `10.42.0.0/24`.
  - LAN and VLAN 42 IPv6 are isolated from each other, mirroring the IPv4 rules.
- **IPv6 WAN policy**: IPv6 is dropped on both WANs in prerouting, input,
  output, and forwarding. No WAN RA, ND, or DHCPv6 handling remains, and no
  IPv6 traffic can enter or leave the edge.
- **Sinkhole Drop Table**: Static rules reject `10.42.0.24` and ULA
  `fd75:c55f:6d19::24`. Both addresses are assigned on `br0`; the sinkhole
  `/64` is unadvertised, so clients without an IPv6 route fail blocked AAAA
  answers locally.

### 4.2 Sysctl Routing Hardening

- `net.ipv4.ip_forward = 1`
- `net.ipv4.conf.all.forwarding = 1`
- `net.ipv6.conf.all.forwarding = 1` (Tailscale plus routing between LAN ULA segments)
- `net.core.default_qdisc = "fq_codel"` (Fair Queuing Controlled Delay bufferbloat prevention)
- `net.netfilter.nf_conntrack_max = 262144`
- `net.netfilter.nf_conntrack_tcp_timeout_established = 7440` (optimized from 5 days)
- `net.ipv4.conf.all.rp_filter = 2` (Loose reverse path filter for multi-WAN)
- `vm.swappiness = 10`

______________________________________________________________________

## 5. DNS & Reverse Proxy Services

### 5.1 Primary DNS Stack

- **AdGuard Home**: DNS binds an explicit address list (`::1`, both segment
  ULAs `fd75:c55f:6d19:1::1` and `fd75:c55f:6d19:2::1`, `127.0.0.1`,
  `10.42.0.1`, `10.42.42.1`, and the Tailscale IPv4 address); the `::`
  wildcard is gone, so
  no listener touches a WAN address. The Web UI remains IPv4. Upstream is
  `[::1]:5335` with `127.0.0.1:5335` as fallback. Custom-IP blocking uses
  `10.42.0.24` and static ULA `fd75:c55f:6d19::24`.
- **Unbound**: Listens on `127.0.0.1:5335` and `[::1]:5335`, with `do-ip6`
  kept on so the `::1` listener exists. Outbound iteration is IPv4 in practice
  because the host holds no IPv6 default route. It retains the IPv4 LAN Valkey
  backend.
- **System resolver**: `::1` first, then `127.0.0.1`. Kea DHCPv4 option 6
  stays IPv4-only; SLAAC clients get the segment ULA through RDNSS.
- **Encrypted DNS**: Serves DoT, DoQ, and DoH on `dns.fufu.land` (853, 3443, nginx `/dns-query` on 443). AGH DDR advertises DoH `:3443` and DoQ `:853` for `_dns.resolver.arpa`; DoT is omitted (no IP SANs). Manual DoT to `:853` still works. No DNR / Kea DHCPv6.

### 5.2 Nginx Ingress Reverse Proxy

- Wildcard ACME certificate for `*.fufu.land` and `fufu.land` via Cloudflare DNS-01 API challenge.
- Access control (`restrictedProxyConfig`): Allows trusted LAN (`10.42.0.0/24`) and VPN CIDRs, denies public access to internal dashboards.
- Virtual hosts proxied to `yifuwuqi` over LAN (`10.42.0.2`):
  - `grafana.fufu.land` $\\to$ Grafana (:24030)
  - `cockpit.fufu.land` $\\to$ Cockpit (:24091)
  - `search.fufu.land` $\\to$ SearXNG (:24888)
  - `attic.fufu.land` $\\to$ Attic Binary Cache (:24203)
  - `git.fufu.land` $\\to$ Forgejo Git (:24200)
  - `prtnr.fufu.land` $\\to$ Portainer (:9443)
  - `agent.fufu.land` $\\to$ Opencode Server (:24010)
  - `sillytavern.fufu.land` $\\to$ SillyTavern (:24000)
  - `radarr.fufu.land` – `sonarr.fufu.land` – `prowlarr.fufu.land` – `jellyfin.fufu.land` – `seerr.fufu.land` – `homepage.fufu.land` (Arr & Media stack)
- Host-local virtual hosts:
  - `adguard.fufu.land` $\\to$ Local AdGuard UI (:3333)
  - `dns.fufu.land` $\\to$ Local AdGuard DoH (:3333/dns-query)
  - `docs.fufu.land` $\\to$ Compiled mdBook documentation
  - `goaccess.fufu.land` $\\to$ Static HTML dashboard + WebSocket proxy (:7890)

______________________________________________________________________

## 6. Observability & Monitoring

- **Vector**: Ships systemd journal logs to central Loki on `yifuwuqi`.
- **GoAccess**: Ingests `/var/log/nginx/access.log`, serves real-time HTML report at `/var/lib/goaccess/index.html`, runs WebSocket daemon on port `7890`.
- **Prometheus Exporters**:
  - `node-exporter` (port 9100, systemd collectors enabled)
  - `systemd-exporter` (port 9558)
  - `smartctl-exporter` (port 9633, 60s scrape interval)
  - `nginx-exporter` (port 9113, status page enabled)
  - `adguard-exporter` (port 9617)
  - `unbound-exporter` (port 9167, connects via unix socket)

______________________________________________________________________

## 7. Key Source Files

- `hosts/yirukou/configuration.nix`
- `hosts/yirukou/services.nix`
- `hosts/yirukou/networking.nix`
- `hosts/yirukou/networking/bridge.nix`
- `hosts/yirukou/networking/dhcp.nix`
- `hosts/yirukou/networking/wans.nix`
- `hosts/yirukou/networking/firewall.nix`
- `hosts/yirukou/networking/untrusted.nix`
- `hosts/yirukou/networking/sysctl.nix`
- `hosts/yirukou/goaccess.nix`
- `modules/networking/gateway-failover.nix`
- `modules/networking/sinkhole.nix`
- `modules/services/nginx-proxy.nix`
- `modules/services/adguardhome.nix`
- `modules/services/unbound.nix`
