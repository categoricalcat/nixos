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

| Interface    | Type     | Address / Subnet                         | Role                                                                                                             |
| ------------ | -------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `eno1`       | Physical | `10.42.0.2/24`, `fd75:c55f:6d19:1::2/64` | Primary dual-stack LAN interface (MTU 1492, DNS `yirukou`, `Domains = ~.`)                                       |
| `enp4s0`     | Physical | Dynamic DHCPv4 in `192.168.0.0/24`       | Secondary/Fallback uplink (`UseGateway = true` at metric 200, `UseRoutes = false`, `UseDNS = true`)              |
| `wlp2s0`     | Wireless | Disabled                                 | Wireless interface explicitly powered down (`ActivationPolicy = down`)                                           |
| `tailscale0` | Tunnel   | `100.69.0.6/32`                          | Tailscale subnet router for `192.168.0.1/32` (`exitNodeHost = null`, no route acceptance, Tailscale SSH enabled) |

### Network Tuning & Sysctl

- **BBR Congestion Control**: `tcp_bbr` kernel module with `fq` queuing discipline.
- **Socket Buffer Ceiling**: 64 MiB max read/write buffers (`net.core.rmem_max = 67108864`, `net.core.wmem_max = 67108864`).
- **Nginx Tail Latency Optimization**: `net.ipv4.tcp_notsent_lowat = 16384` (16 KB bounded un-sent buffer).
- **Foreign Route Preservation**: `ManageForeignRoutes = false` in `packages/gateway-failover/default.nix` prevents `systemd-networkd` from stripping the `wan-monitor` routes whenever it reconfigures a link.
- **LAN-only IPv6**: `eno1` holds the static ULA `fd75:c55f:6d19:1::2/64` and
  sets `IPv6AcceptRA = "no"`, so no advertisement can install a default route
  or a second address. There is no global address and no IPv6 egress; IPv6 is
  used only for host-to-host and host-to-service traffic on the LAN. `enp4s0`
  and `wlp2s0` remain IPv6-disabled, and temporary/privacy addresses are off.
  Why the ISP GUA is unused: [IPv6 ULA vs GUA](../networking/ipv6-ula-gua.md).
- **Per-interface DNS & secondary stub**: `systemd-resolved` runs with
  `Cache = "no"`, `DNSStubListener = "yes"`, and `DNSStubListenerExtra` bound to
  `::1`, `fd75:c55f:6d19:1::2`, `127.0.0.1`, `10.42.0.2`, and `100.69.0.6`.
  `eno1` configures `yirukou` (`fd75:c55f:6d19:1::1`, `10.42.0.1`) with
  `Domains = ~.`, while `enp4s0` sets `UseDNS = true`. Queries from the host,
  Podman containers, and LAN/Tailscale clients using `yifuwuqi` as secondary
  DNS defer to `yirukou` while `eno1` has carrier and automatically fall back
  to `enp4s0` when `eno1` is down, with zero RAM cache or disk writes.
- **Container Isolation Firewall**: Strict nftables rules permitting container subnets (`10.88.0.0/16`, `172.17-18.0.0/16`, `10.89.0.0/24`) to reach host DNS (`10.42.0.2` `systemd-resolved` stub and local `aardvark-dns` bridge gateways) and specific service APIs (Lidarr 24686, SearXNG 24888) while dropping all forwarding to private subnets, redirecting any non-local TCP/UDP `53` container query to `10.42.0.2:53` (`yifuwuqi-dns`), and rejecting off-net container DoT/DoQ (`853`) and DoH (`443` to `publicDnsResolvers.ipv4`).
- **Tailscale UDP GRO**: `tailscale-udp-gro.service` sets
  `rx-udp-gro-forwarding on rx-gro-list off` on `eno1` and `enp4s0` at boot,
  which tailscaled asks for once the host forwards tunnel traffic.
- **Fallback Uplink Subnet Route**: `enp4s0` is the only tailnet foothold in
  `192.168.0.0/24`, so this host advertises `192.168.0.1/32` (that link's
  router) to the tailnet, making its admin UI reachable from tailnet devices
  that accept routes. tailscaled masquerades subnet-route traffic to the
  `enp4s0` address
  ([Tailscale subnet forwarding](../networking/tailscale-subnet-forwarding.md)).

______________________________________________________________________

## 3. Storage, Databases & File Sharing

```text
┌─────────────────────────────────────────────────────────────┐
│                    yifuwuqi Data Storage                    │
├──────────────────────────────┬──────────────────────────────┤
│ PostgreSQL 18 (Socket / VPN) │ databases: forgejo, atticd,  │
│                              │ grafana                      │
├──────────────────────────────┼──────────────────────────────┤
│ Valkey (Redis fork)          │ DB 1: SearXNG rate limiter   │
├──────────────────────────────┼──────────────────────────────┤
│ Samba Server                 │ /srv/shares/share            │
│                              │ /home/yi/the.files           │
├──────────────────────────────┼──────────────────────────────┤
│ WebDAV (Nginx DAV)           │ /srv/webdav                  │
│ File Browser                 │ /home/yi                     │
└──────────────────────────────┴──────────────────────────────┘
```

### 3.1 PostgreSQL 18 Server

- High-performance database server (`services.postgresql`) bound to unix socket and local/VPN networks.
- Databases provisioned: `forgejo`, `atticd`, `grafana`. Superuser `yi` provisioned with full ownership.

### 3.2 Valkey In-Memory Key-Value Store

- Bound to `127.0.0.1` only; consumers use the unix socket `/run/redis/redis.sock`.
- Memory limit: 512 MB with `allkeys-lru` eviction policy.
- **DB 1**: Rate limiting backend for SearXNG. Unbound's L2 cache is the valkey on `yirukou`, not this one.

### 3.3 Samba File Server

- Configured in `modules/services/samba/server.nix`:
  - `share` $\\to$ `/srv/shares/share` (0775 permissions)
  - `the.files` $\\to$ `/home/yi/the.files` (read-only guest, read-write user `yi`)

______________________________________________________________________

## 4. Binary Cache & CI/CD Pipeline

### 4.1 Attic Binary Cache

- **Attic Server (`atticd`)**: Binds `127.0.0.1:24203` behind the local ingress (`cache.aset.love`), PostgreSQL backend, SOPS JWT authentication, chunk sizes 16KB–1MB (avg 256KB), daily garbage collection.
- **Attic Watch-Store (`attic-watch-store.service`)**: Daemon running under user `nix-builder` that watches `/nix/store` and pushes new paths in real time (`-j 10`) via `http://127.0.0.1:24203`.
- **Attic Closure-Keeper (`attic-closure-keeper.timer`)**: Runs every 15 minutes to guarantee all `-nixos-system-` closures are pinned and pushed.

### 4.2 Git Forge & Actions Runners

- **Forgejo (`git.aset.love`)**: Binds `127.0.0.1:24200` behind the local ingress, PostgreSQL backend, Git LFS, repository mirroring, Forgejo Actions enabled (12h task timeout).
- **Forgejo Actions Runner (`forgejo-runner-yifuwuqi`)**: Native host runner (`native:host` label) under `nix-builder` user. Systemd sandbox is intentionally relaxed so builds can access `/nix/store` and mount namespaces. Automatically injects Attic push credentials.
- **GitHub Actions Runner**: Dedicated self-hosted runner targeting `categoricalcat/nixos` with `setup-ci-env` integration.
- **Distributed Builder**: Pinned host keys in `secrets/keys.nix`, accepts up to 16 concurrent Nix build jobs.

______________________________________________________________________

## 5. AI & Local Inference Pipeline

```text
┌─────────────────────────────────────────────────────────────┐
│                   AI Inference & Search                     │
├──────────────────────────────┬──────────────────────────────┤
│ llama.cpp Router (Vulkan)    │ gemma-4-12b (+ uncensored)   │
│ (Radeon 680M APU)            │ port 11436, 32k context      │
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

- **Vulkan llama-cpp Router (`llama-cpp-node`)**: Runs `llama-server` in router mode (`--models-preset` + `--models-max 1`) with Vulkan acceleration (`vulkanSupport = true`) on `127.0.0.1:11436`.
  - Registered presets: **`gemma-4-12b`** (`UD-Q4_K_XL`, thinking enabled) and **`gemma-4-12b-uncensored`** (`Q4_K_M`, direct non-thinking output for roleplay), both at 32,768 context length with FlashAttention, Q8 KV cache, single-slot execution, and 5-minute idle sleep.
- **SillyTavern Companion UI**: Port 24000 (`companion.aset.love`), runs under dedicated user `sillytavern` with strict systemd hardening, depends on `llama-cpp.service`.
- **SearXNG Privacy Metasearch**: Port 24888 (`search.aset.love`), routes all outgoing search queries through Tor SOCKS5 proxy (`127.0.0.1:9050`), uses Valkey DB 1 for rate limiting, generates ephemeral 32-byte secret on startup.
- **Firecrawl Web Scraper**: 5-container Podman topology (`firecrawl-redis`, `firecrawl-postgres`, `firecrawl-rabbitmq`, `firecrawl-playwright`, `firecrawl`), integrated with local SearXNG as search provider.
- **Opencode Daemon**: AI coding agent daemon running as `yi:yi` on port 24010 (`agent.aset.love`), bound to loopback behind the local ingress (`yirukou` proxies to the ingress, which forwards to `127.0.0.1:24010`). It has no authentication, so anything that can pass the ingress (trusted-LAN Nginx clients, tailnet peers via `yirukou`'s `10.42.0.0/24` subnet route) or reach loopback locally can drive it.

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
  - Podgrab podcast catcher (port 24085, `cast.aset.love`): subscribes to external RSS feeds and downloads episodes to `/persist/media/podcasts`. Nothing is published.
  - Recyclarr declarative quality profile sync.

______________________________________________________________________

## 7. Monitoring & Central Observability

- **Prometheus**: Port 24090, 30-day retention, 15-second scrape intervals, dynamic scrape job generation for all gang exporters.
- **Grafana**: Port 24030 (`grafana.aset.love`), PostgreSQL backend, anonymous Viewer role, declarative Nix-provisioned dashboards (Systemd Units, Services Overview, Fail2ban, Prometheus, Loki, Grafana, Postgres, Valkey, AdGuard, Unbound).
- **Loki**: Port 24100, TSDB schema v13, 7-day retention period.
- **Vector**: Ships host journald logs directly to local Loki.
- **Exporters Running**:
  - `node-exporter` (9100), `systemd-exporter` (9558), `smartctl-exporter` (9633)
  - `postgres-exporter` (9187), `redis-exporter` (9121, Valkey unix socket)
  - `fail2ban-exporter` (9191)

______________________________________________________________________

## 8. General Administration & Hosted Services

- **Homepage Dashboard**: Port 24082 (`home.aset.love`), 5-column layout with ping health checks and resource widgets.
- **Cockpit**: Port 24091 (`cockpit.aset.love`), server admin web console with plugins `cockpit-podman`, `cockpit-files`, `cockpit-dockermanager`, `cockpit-machines`, `cockpit-zfs`.
- **Cloudflared**: OCI container connecting Cloudflare Tunnel to remote endpoints.
- **Secondary DNS Stub (`systemd-resolved`)**: Listens on explicit host addresses (`::1`, `fd75:c55f:6d19:1::2`, `127.0.0.1`, `10.42.0.2`, `100.69.0.6` via `DNSStubListenerExtra`, leaving container bridge gateways to `aardvark-dns`) with `Cache = "no"`, deferring queries to `yirukou` on `eno1` or the fallback DHCP DNS on `enp4s0`.
- **Service Sandboxing**: Loki, Vector, opencode, SillyTavern, Seerr, and
  Cockpit adopt `systemdHardening` from `modules/common.nix`; PostgreSQL and
  Loki add loopback `IPAddressAllow`. Documented exceptions: Loki keeps
  `AF_NETLINK` (Go interface autodetect); SillyTavern and Seerr drop
  `MemoryDenyWriteExecute` and allow `@chown` (Node.js JIT and fs layer);
  opencode keeps process-management syscalls and no `ProtectHome` (agent runs
  arbitrary user commands); Cockpit keeps setuid `cockpit-session` (no
  `NoNewPrivileges`/`RestrictSUIDSGID`). Scores (`systemd-analyze security`):
  loki 1.4, vector 1.4, seerr/sillytavern 1.5, opencode 2.6, cockpit 4.9.

______________________________________________________________________

## 9. Key Source Files

- `hosts/yifuwuqi/configuration.nix`
- `hosts/yifuwuqi/services.nix`
- `hosts/yifuwuqi/networking.nix`
- `hosts/yifuwuqi/networking/firewall.nix`
- `hosts/yifuwuqi/networking/sysctl.nix`
- `hosts/yifuwuqi/networking/interfaces/eno1.nix`
- `hosts/yifuwuqi/networking/interfaces/enp4s0.nix`
- `modules/services/attic/server.nix`
- `modules/services/forgejo.nix`
- `modules/services/ai/llama-cpp.nix`
- `modules/services/ai/sillytavern.nix`
- `modules/services/searxng.nix`
- `modules/services/firecrawl.nix`
- `modules/services/monitoring/prometheus.nix`
- `modules/services/monitoring/grafana.nix`
- `modules/services/monitoring/loki.nix`
