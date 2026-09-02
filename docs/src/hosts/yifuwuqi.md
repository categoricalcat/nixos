# Host Profile: yifuwuqi (Core Server & Service Host)

`yifuwuqi` is the primary monolith server, centralized database, monitoring hub, binary cache, media host, and AI inference node in the infrastructure.

______________________________________________________________________

## 1. System & Hardware Specifications

| Component               | Specification                                                                             |
| ----------------------- | ----------------------------------------------------------------------------------------- |
| **Role**                | Central Application Server, Attic Cache, DB, Monitoring, AI, Media                        |
| **Architecture**        | `x86_64-linux` (AMD APU Platform)                                                         |
| **GPU / Acceleration**  | AMD Radeon 680M Integrated Graphics (~9.6 GB UMA shared memory)                           |
| **Kernel & Boot**       | Linux kernel with `sd_mod`, `amdgpu`, `nft_masq`; systemd-boot (limit 15)                 |
| **Filesystems**         | Ext4 root (`f4da9378-1ca6-4261-94c9-05446f4a89b5`), VFAT `/boot` (`E9B8-1C69`), no swap   |
| **Memory / Swap**       | ZRAM-optimized swap (`vm.swappiness = 180`, `vm.page-cluster = 0`)                        |
| **Power Profile**       | 24/7 server mode (`performance` governor, power management sleep disabled, weekly fstrim) |
| **Secrets Integration** | Sops-nix with host ED25519 SSH key (`/persist/keys/ssh/ssh_host_ed25519_key`)             |

______________________________________________________________________

## 2. Network Topology & Interfaces

### Interface Assignments

| Interface    | Type     | Address / Subnet                | Role                                                                   |
| ------------ | -------- | ------------------------------- | ---------------------------------------------------------------------- |
| `eno1`       | Physical | `10.42.0.2/24`, `10.42.0.24/24` | Primary LAN interface (MTU 1492, `ManageForeignRoutes = false`)        |
| `enp4s0`     | Physical | Dynamic DHCPv4                  | Secondary/Fallback uplink (`UseRoutes = false`, `UseDNS = false`)      |
| `wlp2s0`     | Wireless | Disabled                        | Wireless interface explicitly powered down (`ActivationPolicy = down`) |
| `tailscale0` | Tunnel   | `100.69.0.6/32`                 | Tailscale client mode (`exitNodeHost = null`, Tailscale SSH enabled)   |
| `netbird0`   | Tunnel   | `100.42.0.2/16`                 | NetBird mesh client                                                    |

### Network Tuning & Sysctl

- **BBR Congestion Control**: `tcp_bbr` kernel module with `fq` queuing discipline.
- **Socket Buffer Ceiling**: 64 MiB max read/write buffers (`net.core.rmem_max = 67108864`, `net.core.wmem_max = 67108864`).
- **Nginx Tail Latency Optimization**: `net.ipv4.tcp_notsent_lowat = 16384` (16 KB bounded un-sent buffer).
- **Foreign Route Preservation**: `ManageForeignRoutes = false` in `eno1.nix` prevents `systemd-networkd` from stripping the Keepalived default route on daemon reload.
- **Container Isolation Firewall**: Strict nftables rules permitting container subnets (`10.88.0.0/16`, `172.17-18.0.0/16`) to reach host DNS and specific service APIs (Lidarr 24686, SearXNG 24888) while dropping all forwarding to private subnets.

______________________________________________________________________

## 3. Storage, Databases & File Sharing

```text
┌─────────────────────────────────────────────────────────────┐
│                    yifuwuqi Data Storage                    │
├──────────────────────────────┬──────────────────────────────┤
│ PostgreSQL 18 (Socket / VPN) │ databases: forgejo, atticd,  │
│                              │ grafana                      │
├──────────────────────────────┼──────────────────────────────┤
│ Valkey (Redis fork)          │ DB 0: Unbound L2 DNS Cache   │
│                              │ DB 1: SearXNG Rate Limiter   │
├──────────────────────────────┼──────────────────────────────┤
│ Samba Server                 │ /srv/shares/share            │
│                              │ /home/yi/the.files           │
├──────────────────────────────┼──────────────────────────────┤
│ WebDAV (Nginx DAV)           │ /srv/webdav                  │
└──────────────────────────────┴──────────────────────────────┘
```

### 3.1 PostgreSQL 18 Server

- High-performance database server (`services.postgresql`) bound to unix socket and local/VPN networks.
- Databases provisioned: `forgejo`, `atticd`, `grafana`. Superuser `yi` provisioned with full ownership.

### 3.2 Valkey In-Memory Key-Value Store

- Bound to `0.0.0.0:24379` with `protected-mode no` (firewall-protected).
- Memory limit: 1 GB with `allkeys-lru` eviction policy.
- **DB 0**: Shared L2 DNS cache for Unbound instances on both `yifuwuqi` and `yirukou`.
- **DB 1**: Rate limiting backend for SearXNG.

### 3.3 Samba File Server

- Configured in `modules/services/samba/server.nix`:
  - `share` $\\to$ `/srv/shares/share` (0775 permissions)
  - `the.files` $\\to$ `/home/yi/the.files` (read-only guest, read-write user `yi`)

______________________________________________________________________

## 4. Binary Cache & CI/CD Pipeline

### 4.1 Attic Binary Cache

- **Attic Server (`atticd`)**: Port `24203` (`attic.fufu.land`), PostgreSQL backend, SOPS JWT authentication, chunk sizes 16KB–1MB (avg 256KB), daily garbage collection.
- **Attic Watch-Store (`attic-watch-store.service`)**: Daemon running under user `nix-builder` that watches `/nix/store` and pushes new paths in real time (`-j 10`).
- **Attic Closure-Keeper (`attic-closure-keeper.timer`)**: Runs every 15 minutes to guarantee all `-nixos-system-` closures are pinned and pushed.

### 4.2 Git Forge & Actions Runners

- **Forgejo (`git.fufu.land`)**: Port 24200, PostgreSQL backend, Git LFS, repository mirroring, Forgejo Actions enabled (12h task timeout).
- **Forgejo Actions Runner (`gitea-runner-yifuwuqi`)**: Native host runner (`native:host` label) under `nix-builder` user. Systemd sandbox is intentionally relaxed so builds can access `/nix/store` and mount namespaces. Automatically injects Attic push credentials.
- **GitHub Actions Runner**: Dedicated self-hosted runner targeting `categoricalcat/nixos` with `setup-ci-env` integration.
- **Distributed Builder**: Pinned host keys in `secrets/keys.nix`, accepts up to 16 concurrent Nix build jobs.

______________________________________________________________________

## 5. AI & Local Inference Pipeline

```text
┌─────────────────────────────────────────────────────────────┐
│                   AI Inference & Search                     │
├──────────────────────────────┬──────────────────────────────┤
│ llama.cpp (Vulkan)           │ qwen3.6-35b-abliterated      │
│ (Radeon 680M APU)            │ port 11437, 16k context      │
├──────────────────────────────┼──────────────────────────────┤
│ SillyTavern Web UI           │ port 24000, hardened systemd │
├──────────────────────────────┼──────────────────────────────┤
│ SearXNG (Tor SOCKS5)         │ port 24888, "yi search"      │
├──────────────────────────────┼──────────────────────────────┤
│ Firecrawl (5 Containers)     │ port 24002, SearXNG search   │
├──────────────────────────────┼──────────────────────────────┤
│ Opencode Server              │ port 24010, agent daemon     │
└──────────────────────────────┴──────────────────────────────┘
```

- **Vulkan llama-cpp Serving (`llama-cpp-node`)**: Runs `llama-server` instances with Vulkan acceleration (`vulkanSupport = true`) on the Radeon 680M APU.
  - Active model: **`qwen3.6-35b-abliterated`** (port `11437`, IQ2_M quantization, 16,384 context length, FlashAttention enabled, Q8 KV cache, 5-minute idle sleep).
- **SillyTavern Companion UI**: Port 24000 (`sillytavern.fufu.land`), runs under dedicated user `sillytavern` with strict systemd hardening, depends on `llama-cpp-qwen3-6-35b-abliterated.service`.
- **SearXNG Privacy Metasearch**: Port 24888 (`search.fufu.land`), routes all outgoing search queries through Tor SOCKS5 proxy (`127.0.0.1:9050`), uses Valkey DB 1 for rate limiting, generates ephemeral 32-byte secret on startup.
- **Firecrawl Web Scraper**: 5-container Podman topology (`firecrawl-redis`, `firecrawl-postgres`, `firecrawl-rabbitmq`, `firecrawl-playwright`, `firecrawl`), integrated with local SearXNG as search provider.
- **Opencode Daemon**: AI coding agent daemon running as `yi:yi` on port 24010 (`agent.fufu.land`).

______________________________________________________________________

## 6. Media & Arr Stack

Running in a secure hybrid arrangement: network-isolated containers share a ProtonVPN namespace, while management services run natively on host.

- **VPN Network Namespace (Gluetun)**: OCI container running ProtonVPN WireGuard tunnel.
  - **qBittorrent**: Web UI on port `8080` inside Gluetun namespace, published on the host as `24080`.
  - **Slskd & Soularr**: Soulseek daemon (web `24530` inside the namespace and on the host) and automated downloader inside Gluetun namespace.
  - **FlareSolverr**: listens on `8191` inside Gluetun, published on the host as `24191`.
  - **Torrent-Indexer**: `24181` inside Gluetun and on the host.
- **Native Host Media Daemons**:
  - Radarr (port 24878), Sonarr (port 24989), Lidarr (port 24686), Readarr (port 24787), Bazarr (port 24767), Prowlarr (port 24696).
  - Jellyfin Media Server (port 24096), Jellyseerr / Seerr (port 24055).
  - Recyclarr declarative quality profile sync.

______________________________________________________________________

## 7. Monitoring & Central Observability

- **Prometheus**: Port 24090, 30-day retention, 15-second scrape intervals, dynamic scrape job generation for all fleet exporters.
- **Grafana**: Port 24030 (`grafana.fufu.land`), PostgreSQL backend, anonymous Viewer role, declarative Nix-provisioned dashboards (Systemd Units, Services Overview, Fail2ban, Prometheus, Loki, Grafana, Postgres, Valkey, AdGuard, Unbound).
- **Loki**: Port 24100, TSDB schema v13, 7-day retention period.
- **Vector**: Ships host journald logs directly to local Loki.
- **Exporters Running**:
  - `node-exporter` (9100), `systemd-exporter` (9558), `smartctl-exporter` (9633)
  - `postgres-exporter` (9187), `redis-exporter` (9121, Valkey unix socket)
  - `fail2ban-exporter` (9191)
  - `adguard-exporter` (9617), `unbound-exporter` (9167)

______________________________________________________________________

## 8. General Administration & Hosted Services

- **Homepage Dashboard**: Port 24082 (`homepage.fufu.land`), 5-column layout with ping health checks and resource widgets.
- **Cockpit**: Port 24091 (`cockpit.fufu.land`), server admin web console.
- **Portainer CE**: Port 9443 (`prtnr.fufu.land`), Podman container management.
- **Cloudflared**: OCI container connecting Cloudflare Tunnel to remote endpoints.
- **AdGuard Home & Unbound**: Secondary resolver instance (`10.42.0.2:53` $\\to$ `127.0.0.1:5335`), web UI on port 24333.

______________________________________________________________________

## 9. Key Source Files

- `hosts/yifuwuqi/configuration.nix`
- `hosts/yifuwuqi/services.nix`
- `hosts/yifuwuqi/networking.nix`
- `hosts/yifuwuqi/networking/firewall.nix`
- `hosts/yifuwuqi/networking/sysctl.nix`
- `hosts/yifuwuqi/networking/interfaces/eno1.nix`
- `hosts/yifuwuqi/networking/interfaces/enp4s0.nix`
- `hosts/yifuwuqi/portainer.nix`
- `modules/services/attic/server.nix`
- `modules/services/forgejo.nix`
- `modules/services/ai/llama-cpp.nix`
- `modules/services/ai/sillytavern.nix`
- `modules/services/searxng.nix`
- `modules/services/firecrawl.nix`
- `modules/services/monitoring/prometheus.nix`
- `modules/services/monitoring/grafana.nix`
- `modules/services/monitoring/loki.nix`
