# Hosted Services

The monolith server (`yifuwuqi`) runs several central web applications, management tools, and background daemons for the infrastructure.

All services are configured in `modules/services/` and enabled selectively via `hosts/yifuwuqi/services.nix`. Most services are internal-only, bound to the trusted LAN (`10.42.0.0/24`) and Tailscale mesh, terminated through `yirukou`'s Nginx reverse proxy.

______________________________________________________________________

## 1. Services Overview Table

| Service          | Module File          | Internal Port | Public / Proxy Domain   | Primary Backend / Database          | Description                                                        |
| ---------------- | -------------------- | ------------- | ----------------------- | ----------------------------------- | ------------------------------------------------------------------ |
| **Homepage**     | `homepage.nix`       | `8082`        | `homepage.fufu.land`    | Native YAML                         | Categorized dashboard with real-time health checks & widgets       |
| **Docs**         | `docs.nix`           | `8083`        | `docs.fufu.land`        | mdBook + Nginx                      | Fleet documentation & architectural plans                          |
| **SearXNG**      | `searxng.nix`        | `8888`        | `search.fufu.land`      | Tor SOCKS5 + Valkey DB 1            | Privacy-respecting metasearch engine ("yi search")                 |
| **Valkey**       | `valkey.nix`         | `6379`        | *Internal only*         | In-Memory (1GB LRU)                 | Redis fork; shared L2 DNS cache for Unbound & SearXNG rate limiter |
| **Cockpit**      | `cockpit.nix`        | `9090`        | `cockpit.fufu.land`     | Native D-Bus / sysstat              | Web-based system management & metrics dashboard                    |
| **WebDAV**       | `webdav.nix`         | `80 / 443`    | `webdav.fufu.land`      | Nginx DAV module                    | Direct WebDAV file storage at `/srv/webdav`                        |
| **Firecrawl**    | `firecrawl.nix`      | `3002`        | *Internal API*          | 5 OCI Containers + SearXNG          | LLM web scraping & document extraction engine                      |
| **SillyTavern**  | `ai/sillytavern.nix` | `8000`        | `sillytavern.fufu.land` | `llama-cpp-qwen3-6-35b-abliterated` | Advanced conversational frontend & AI persona manager              |
| **Opencode**     | `opencode.nix`       | `3010`        | `agent.fufu.land`       | Native Agent Daemon                 | Autonomous AI coding agent backend                                 |
| **Portainer CE** | `portainer.nix`      | `9443`        | `prtnr.fufu.land`       | Podman Socket                       | Container lifecycle & volume management web UI                     |
| **Cloudflared**  | `cloudflared.nix`    | *Dynamic*     | *Tunnel Egress*         | OCI Container                       | Zero-trust Cloudflare Tunnel connector                             |
| **Tor Client**   | `services.tor`       | `9050`        | *Internal SOCKS5*       | Tor Onion Router                    | Anonymous routing proxy for outbound SearXNG requests              |

______________________________________________________________________

## 2. Service Architecture & Implementation Details

### 2.1 Homepage Dashboard (`modules/services/homepage.nix`)

- **Web UI**: Served at `http://10.42.0.2:8082` and proxied to `https://homepage.fufu.land`.
- **Layout Architecture**: 4-column responsive grid with 5 main service groups:
  1. **Media**: Jellyfin, Jellyseerr.
  1. **Arr Stack**: Sonarr, Radarr, Lidarr, Readarr, Bazarr, Prowlarr, Torrent Indexer, qBittorrent, Soulseek (`slskd`).
  1. **Monitoring**: Grafana (`grafana.fufu.land`), GoAccess (`goaccess.fufu.land`).
  1. **Infrastructure**: Cockpit, Portainer, Forgejo, Opencode Agent, Attic Binary Cache.
  1. **Network**: AdGuard Home, SearXNG.
- **Widgets**: Real-time CPU, RAM, and root filesystem disk utilization monitors, plus an integrated search bar pointing to SearXNG.

### 2.2 SearXNG ("yi search") (`modules/services/searxng.nix`)

- **Web UI**: Served at `http://10.42.0.2:8888` and proxied to `https://search.fufu.land`.
- **Tor Proxy Routing**: All outbound search queries are forced through the local Tor SOCKS5 proxy (`socks5h://127.0.0.1:9050`) to conceal client IP addresses from upstream search providers.
- **Engines Enabled**: DuckDuckGo (`ddg`), Mojeek (`mjk`), Google Scholar (`gs`), and arXiv (`ar`). Google web search is intentionally disabled to avoid Tor CAPTCHA blocking.
- **Ephemeral Secret Generation**: `searx-secret-init.service` automatically generates a cryptographically random 32-byte hex secret key on boot into `/run/searx-secret/env` mode `0440`.
- **Startup Coordination**: `wait-for-tor.service` probes `https://check.torproject.org/api/ip` over Tor before allowing SearXNG to launch, preventing startup race conditions.

### 2.3 Valkey Datastore (`modules/services/valkey.nix`)

- **Service**: In-memory Redis-compatible key-value store running on `0.0.0.0:6379`.
- **Memory Management**: 1 GB maximum RAM allocation with `allkeys-lru` eviction policy.
- **Multi-Tenant Usage**:
  - **DB 0**: Shared L2 DNS cache for Unbound instances across `yifuwuqi` and `yirukou`.
  - **DB 1**: Rate limiting token bucket storage for SearXNG accessed over unix socket `/run/redis/redis.sock`.

### 2.4 Firecrawl Web Scraper Stack (`modules/services/firecrawl.nix`)

Runs 5 coordinated OCI containers under Podman across two network segments:

- **Networks**: `firecrawl_net` (egress) and `firecrawl_internal` (isolated internal bridge).
- **Containers**:
  1. `firecrawl-redis`: Transient queue storage.
  1. `firecrawl-postgres`: Relational data store (`nuq-postgres`).
  1. `firecrawl-rabbitmq`: Message broker for scraping job queues.
  1. `firecrawl-playwright`: Headless browser automation service (`MAX_CONCURRENT_PAGES = 10`).
  1. `firecrawl`: Core API daemon, integrated directly with local SearXNG as its search provider.

### 2.5 SillyTavern Companion UI (`modules/services/ai/sillytavern.nix`)

- **Web UI**: Served at `http://10.42.0.2:8000` and proxied to `https://sillytavern.fufu.land`.
- **Security Context**: Dedicated non-root user `sillytavern` with strict systemd filesystem isolation (`ProtectSystem = strict`, `ProtectHome = true`, `PrivateDevices = true`, `PrivateTmp = true`).
- **Inference Integration**: Depends directly on the local `llama-cpp-qwen3-6-35b-abliterated.service` Vulkan instance.

### 2.6 Cockpit System Manager (`modules/services/cockpit.nix`)

- **Web UI**: Port `9090` (`https://cockpit.fufu.land`).
- **Configuration**: Configured with `WebService.AllowUnencrypted = true` to work seamlessly behind Nginx SSL termination, with explicit origin whitelisting across LAN, VPN, and FQDN. Includes `pkgs.sysstat` for historical performance graphing.

### 2.7 WebDAV Server (`modules/services/webdav.nix`)

- **Web UI**: `https://webdav.fufu.land`.
- **Configuration**: Built using `pkgs.nginxModules.dav`, root directory `/srv/webdav` (mode 0775, `nginx:nginx`), unlimited client max body size (`client_max_body_size 0`), support for all standard WebDAV methods (`PUT`, `DELETE`, `MKCOL`, `COPY`, `MOVE`, `PROPFIND`, `OPTIONS`, `LOCK`, `UNLOCK`).

### 2.8 Fleet Documentation (`modules/services/docs.nix`)

- **Web UI**: Served at `http://10.42.0.2:8083` and proxied to `https://docs.fufu.land`.
- **Real-Time Auto-Builder**: Watchexec monitors `/home/yi/the.files/nixos/docs` on `yifuwuqi` (debounced by 1500ms).
- **Out-of-Tree RAM Staging**: Dynamically generates `# Architecture Plans & RFCs` navigation from `src/plans/*.md` inside `/run/fleet-docs/staging` without modifying the git repository.
- **Serving Daemon**: `darkhttpd` serves `/var/lib/fleet-docs/book` under `DynamicUser = true` with strong systemd sandboxing (`ProtectHome = true`, `SystemCallFilter = [...]`).

______________________________________________________________________

## 3. Key Source Files

- `modules/services/docs.nix`
- `modules/services/homepage.nix`
- `modules/services/searxng.nix`
- `modules/services/valkey.nix`
- `modules/services/firecrawl.nix`
- `modules/services/ai/sillytavern.nix`
- `modules/services/cockpit.nix`
- `modules/services/webdav.nix`
- `hosts/yifuwuqi/portainer.nix`
- `hosts/yifuwuqi/services.nix`
