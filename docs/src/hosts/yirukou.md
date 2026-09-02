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
                        │   │ └── 10.42.42.1/24 (Guest/IoT)│   │
                        │   └──────────────────────────────┘   │
                        │   ┌──────────────────────────────┐   │
                        │   │ Tailscale (100.69.0.1/32)    │   │
                        │   │ └── Subnet Router + Exit Node│   │
                        │   └──────────────────────────────┘   │
                        └──────────────────────────────────────┘
```

### Interface Assignments

| Interface    | Type        | Address / Subnet                | Role                                                                     |
| ------------ | ----------- | ------------------------------- | ------------------------------------------------------------------------ |
| `enp7s0`     | Physical    | Dynamic DHCPv4                  | Primary WAN uplink (Route metric 100, `UseRoutes = false`)               |
| `enp6s0`     | Physical    | Dynamic DHCPv4                  | Secondary/Fallback WAN uplink (Route metric 200, `UseRoutes = false`)    |
| `br0`        | Bridge      | `10.42.0.1/24`, `10.42.0.24/24` | Trusted LAN bridge enslaving physical ports `enp5s0`, `enp4s0`, `enp3s0` |
| `enp2s0.42`  | 802.1Q VLAN | `10.42.42.1/24`                 | Untrusted / Guest VLAN 42 on parent port `enp2s0`                        |
| `tailscale0` | Tunnel      | `100.69.0.1/32`                 | Tailscale mesh interface (`both` mode: subnet router + exit node)        |

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
  - `br0` (LAN): TCP `53` (DNS), `80` (HTTP), `443` (HTTPS), `853` (DoT), `24212` (SSH); UDP `53` (DNS), `67` (DHCP), `853` (DoT).
  - `enp2s0.42` (Untrusted): TCP `53`, `80`, `443`, `853`; UDP `53`, `67`, `853` (SSH is blocked).
  - `tailscale0`: TCP `24212` (SSH).
  - WANs (`enp7s0`, `enp6s0`): UDP `51820` (Tailscale / WireGuard).
- **Bogon Filtering**: Raw prerouting chain drops 14 IPv4 bogon subnets (`0.0.0.0/8`, `10.0.0.0/8`, `100.64.0.0/10`, `127.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, etc.) and 11 IPv6 bogon subnets entering WAN interfaces.
- **Forwarding & NAT**:
  - Outbound NAT masquerading on WANs for LAN, VLAN 42, and Tailscale traffic.
  - Forwarding enabled between Tailscale and LAN subnet `10.42.0.0/24`.
- **Sinkhole Drop Table**: `inet sinkhole` immediately rejects queries to `10.42.0.24` and `2001:db8::2` with `tcp reset` / `icmp host-unreachable`.

### 4.2 Sysctl Routing Hardening

- `net.ipv4.ip_forward = 1`
- `net.core.default_qdisc = "fq_codel"` (Fair Queuing Controlled Delay bufferbloat prevention)
- `net.netfilter.nf_conntrack_max = 262144`
- `net.netfilter.nf_conntrack_tcp_timeout_established = 7440` (optimized from 5 days)
- `net.ipv4.conf.all.rp_filter = 2` (Loose reverse path filter for multi-WAN)
- `vm.swappiness = 10`

______________________________________________________________________

## 5. DNS & Reverse Proxy Services

### 5.1 Primary DNS Stack

- **AdGuard Home**: Listens on `0.0.0.0:53` (Web UI on `3333`). Optimistic 64 MiB caching, Hagezi Multi PRO++ and TIF blocklists, DNS rewrites (`*.fufu.land` $\\to$ `10.42.0.1`, `smb.fufu.land` $\\to$ `10.42.0.2`).
- **Unbound**: Listens on `127.0.0.1:5335`. Handles recursive resolution, connects to remote Valkey L2 cache on `yifuwuqi` (`10.42.0.2:24379`), extended statistics via `/run/unbound/unbound.ctl`.
- **Encrypted DNS**: Serves DoT, DoQ, and DoH on `dns.fufu.land` (ports 853, 3443).

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
