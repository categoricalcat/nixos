# Hosted Services

The monolith server (`yifuwuqi`) runs several central web applications, management tools, and background daemons for the infrastructure.

All services are configured in `modules/services/` and enabled selectively via `hosts/yifuwuqi/services.nix`. Most services are internal-only, bound to loopback (`127.0.0.1`) and fronted by the `yifuwuqi` local ingress (`modules/services/local-ingress.nix`), a single nginx listener on the LAN address that routes each domain to its backend. `yirukou`'s Nginx reverse proxy terminates TLS and forwards every domain to that ingress. A few services that cannot bind loopback (jellyfin, jellyseerr, homepage, lidarr) keep the LAN address and are fronted there too.

______________________________________________________________________

## 1. Services Directory (generated)

This directory renders every registry service entry from
`modules/addresses.nix` (`docs/src/generated/services.md`, flake package
`docs-generated`; the `docs-registry-sync` check blocks drift). Narrative,
backends, and implementation detail for each service follow in section 2.

{{#include ../generated/services.md}}

______________________________________________________________________

## 2. Service Architecture & Implementation Details

### 2.1 Homepage Dashboard (`modules/services/homepage.nix`)

- **Web UI**: Served at `http://10.42.0.2:24082` (LAN; homepage has no loopback bind option) and proxied to `https://home.aset.love` via the local ingress.
- **Layout Architecture**: 4-column responsive grid with 5 main service groups:
  1. **Media**: Jellyfin, Jellyseerr, Pinepods (`cast.aset.love`, podcast catcher).
  1. **Arr Stack**: Sonarr, Radarr, Lidarr, Readarr, Bazarr, Prowlarr, Torrent Indexer, qBittorrent, Soulseek (`slskd`).
  1. **Monitoring**: Grafana (`grafana.aset.love`), GoAccess (`goaccess.aset.love`).
  1. **Infrastructure**: Cockpit, Files, Forgejo, Opencode Agent, Attic Binary Cache.
  1. **Network**: AdGuard Home, SearXNG.
- **Widgets**: Real-time CPU, RAM, and root filesystem disk utilization monitors, plus an integrated search bar pointing to SearXNG.

### 2.2 SearXNG ("yi search") (`modules/services/searxng.nix`)

- **Web UI**: Binds all interfaces (`0.0.0.0:24888`, not loopback — the Firecrawl container reaches it via `host.containers.internal`) and is proxied to `https://search.aset.love` through the local ingress. The firewall scopes the exposure: `eno1` admits only declared ports plus the `yirukou` gateway (which reaches the local ingress and Loki, not SearXNG directly), `tailscale0` only SSH and DNS, and an explicit input rule admits the application-container subnets to the SearXNG port.
- **Tor Proxy Routing**: Outbound search queries round-robin across 4 dummy-credential SOCKS5 endpoints (`socks5h://pool{1..4}:x@127.0.0.1:9050`), using Tor's default `IsolateSOCKSAuth` for 4 independent exit circuits. `services.tor` caps `CircuitBuildTimeout` at `10s`, `MaxCircuitDirtiness` at `180s`, and `SocksTimeout` at `30s`. `brave`, `brave.news`, `duckduckgo`, and `duckduckgo news` each use a dedicated network with 3 retries on HTTP `403`/`429` (plus `202` for DuckDuckGo CAPTCHA challenges) to rotate across all 4 exit circuits, and `ban_time_on_fail = 0` prevents a single stalled exit from suspending an engine across fresh circuits.
- **Engines Enabled**: Upstream defaults (Brave, DuckDuckGo, Bing News, Wikinews, etc.) plus Google Scholar (`gs`) and arXiv (`ar`), with `duckduckgo` (omitting redundant explicit `Content-Type` header so `curl_cffi` keeps standard `Content-Length` -> `Content-Type` order and avoids HTTP `202` CAPTCHAs), `duckduckgo_extra` (removing hardcoded 2s `fetch_vqd` timeout), and `bing_news` (guarding empty HTTP 200 bodies) patched in Nix. Google web/news/CSE, Reuters (HTTP 401), Radio Browser (unproxied DNS during `init()`), and Wikidata (HTTP 403) are disabled; Mojeek, Startpage, Ahmia, and Torch stay inactive.
- **Ephemeral Secret Generation**: `searx-secret-init.service` automatically generates a cryptographically random 32-byte hex secret key on boot into `/run/searx-secret/env` mode `0440`.
- **Startup Coordination**: `using_tor_proxy` is intentionally left unset so `searx.service` (`Type=simple`) starts after `network-online.target`, `tor.service`, and `redis.service` without blocking `multi-user.target` on an external Tor circuit probe.

### 2.3 Valkey Datastore (`modules/services/valkey.nix`)

- **Service**: In-memory Redis-compatible key-value store. Runs on **both** `yifuwuqi` and `yirukou`, bound to `127.0.0.1` only; every consumer is host-local and connects over the unix socket `/run/redis/redis.sock`. Nothing reaches it across the LAN.
- **Memory Management**: `allkeys-lru` eviction, sized in `modules/addresses/hosts.nix` (`services.valkey.maxMemory`) — 1 GB on `yirukou` (primary resolver), 512 MB on `yifuwuqi`.
- **Multi-Tenant Usage**:
  - **DB 0**: L2 DNS cache for Unbound on `yirukou`. Not shared between hosts — see [Unbound Architecture](../networking/unbound-integration.md) for why cachedb must not cross a link.
  - **DB 1**: Rate limiting token bucket storage for SearXNG (`yifuwuqi` only), over the same unix socket.

### 2.4 Firecrawl Web Scraper Stack (`modules/services/firecrawl.nix`)

Runs 5 coordinated OCI containers under Podman across two network segments:

- **Networks**: `firecrawl_net` (egress) and `firecrawl_internal` (isolated internal bridge).
- **Containers**:
  1. `firecrawl-redis`: Transient queue storage.
  1. `firecrawl-postgres`: Relational data store (`nuq-postgres`).
  1. `firecrawl-rabbitmq`: Message broker for scraping job queues.
  1. `firecrawl-playwright`: Headless browser automation service (`MAX_CONCURRENT_PAGES = 10`).
  1. `firecrawl`: Core API daemon, integrated directly with local SearXNG as its search provider. Published on `127.0.0.1:24002` only — podman forwards published ports by DNAT and the host firewall accepts every DNAT'd connection, so the per-interface allowlists never cover a published port and the publish address itself carries the loopback restriction. Runs a single NuQ worker (`NUQ_WORKER_COUNT = 1`): `/v2/scrape` and `/v2/map` run inside the API process, the workers serve only the crawl and batch endpoints, and one worker keeps those alive one job at a time while freeing ~970 MiB against the default five.

### 2.5 SillyTavern Companion UI (`modules/services/ai/sillytavern.nix`)

- **Web UI**: Bound to loopback behind the local ingress and proxied to `https://companion.aset.love`.
- **Security Context**: Dedicated non-root user `sillytavern` with strict systemd filesystem isolation (`ProtectSystem = strict`, `ProtectHome = true`, `PrivateDevices = true`, `PrivateTmp = true`).
- **Inference Integration**: Ordered after the local `llama-cpp.service` Vulkan router; the endpoint (`http://127.0.0.1:11436/v1`) and model are selected in the SillyTavern UI.

### 2.6 Cockpit System Manager (`modules/services/cockpit.nix`)

- **Web UI**: Port `24091` (`https://cockpit.aset.love`).
- **Configuration**: Configured with `WebService.AllowUnencrypted = true` to work seamlessly behind Nginx SSL termination, with explicit origin allowlisting across LAN, VPN, and FQDN. Includes `pkgs.sysstat` for historical performance graphing. The Kernel dump page is hidden (`/etc/cockpit/kdump.override.json`): NixOS `kexec` is for fast reboot, not Fedora's `kdump.service`, and that page only shows a false "install kexec-tools" alert.
- **Plugins**: `cockpit-podman` (Podman containers, replaces the former Portainer CE deployment; PAM login), `cockpit-files` (file browser), `cockpit-dockermanager`, `cockpit-machines` (libvirt UI), `cockpit-zfs` (ZFS UI). The last two only add the pages; libvirt and ZFS are not enabled on this host.

### 2.7 WebDAV Server (`modules/services/webdav.nix`, dormant)

- **Status**: Disabled (commented out in `hosts/yifuwuqi/services.nix` and absent from the active registry directory above).
- **Configuration**: Built using `pkgs.nginxModules.dav` (`https://webdav.aset.love`), root directory `/srv/webdav` (mode 0775, `nginx:nginx`), unlimited client max body size (`client_max_body_size 0`), support for all standard WebDAV methods (`PUT`, `DELETE`, `MKCOL`, `COPY`, `MOVE`, `PROPFIND`, `OPTIONS`, `LOCK`, `UNLOCK`).

### 2.8 File Browser (`modules/services/filebrowser.nix`)

- **Web UI**: Bound to loopback `127.0.0.1:24086` behind the local ingress and proxied to `https://files.aset.love`.
- **Login**: username `yi` with SOPS `passwords/filebrowser`. This is not the unix password.
- **Scope**: `/home/yi`, read-only. Download is the only permission. Dotfiles are visible; `/the.files/nixos/secrets` is denied.

### 2.9 Gang Documentation (`docs/service.nix`)

- **Web UI**: Bound to loopback behind the local ingress and proxied to `https://docs.aset.love`.
- **Real-Time Auto-Builder**: Watchexec monitors `/home/yi/the.files/nixos/docs` on `yifuwuqi` (debounced by 1500ms).
- **Out-of-Tree RAM Staging**: Copies the bind-mounted `docs/` tree into a `mktemp` directory and dynamically appends the `# Architecture Plans & RFCs` navigation from `src/plans/*.md` there, without modifying the git repository.
- **Serving Daemon**: `darkhttpd` serves `/var/lib/gang-docs/book` as the dedicated `docs` system user with strong systemd sandboxing (`ProtectHome = true`, `SystemCallFilter = [...]`).

______________________________________________________________________

## 3. Key Source Files

- `docs/service.nix`
- `modules/services/homepage.nix`
- `modules/services/searxng.nix`
- `modules/services/valkey.nix`
- `modules/services/firecrawl.nix`
- `modules/services/ai/sillytavern.nix`
- `modules/services/cockpit.nix`
- `modules/services/webdav.nix`
- `modules/services/filebrowser.nix`
- `hosts/yifuwuqi/services.nix`
