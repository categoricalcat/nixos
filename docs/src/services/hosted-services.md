# Hosted Services

The monolith server (`yifuwuqi`) runs several central web applications, management tools, and background daemons for the infrastructure.

All services are configured in `modules/services/` and enabled selectively via `hosts/yifuwuqi/services.nix`. Most services are internal-only, bound to loopback (`127.0.0.1`) and fronted by the `yifuwuqi` local ingress (`modules/services/local-ingress.nix`), a single nginx listener on the LAN address that routes each domain to its backend. `yirukou`'s Nginx reverse proxy terminates TLS and forwards every domain to that ingress. A few services that cannot bind loopback (jellyfin, jellyseerr, homepage, lidarr) keep the LAN address and are fronted there too.

Logins: Authelia is the one login in front of every browser-facing service ([the gate](dns-and-proxy.md#221-authelia-gate-forward-auth)), and Vaultwarden is the one store for every credential a person still holds. Services drop their own login wherever they can: the \*arr apps, Bazarr, slskd and Grafana have none, and OpenCode's password is presented by the ingress. The remaining exceptions are named. Cockpit logs into OS accounts (PAM), Forgejo and Seerr keep their own login behind the gate, and Jellyfin and Pinepods stay outside it for their native clients.

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

- **Web UI**: Served at `http://10.42.0.2:24082` (LAN; homepage has no loopback bind option) and proxied to `https://homepage.aset.love` via the local ingress.
- **Layout Architecture**: 4-column responsive grid with 5 main service groups:
  1. **Media**: Jellyfin, Jellyseerr, Pinepods (`pinepods.aset.love`, podcast catcher).
  1. **Arr Stack**: Sonarr, Radarr, Lidarr, Readarr, Bazarr, Prowlarr, Torrent Indexer, qBittorrent, Soulseek (`slskd`).
  1. **Monitoring**: Grafana (`grafana.aset.love`), GoAccess (`goaccess.aset.love`).
  1. **Infrastructure**: Cockpit (with File browser), Forgejo, Opencode Agent, SillyTavern, Attic Binary Cache, Docs, Authelia, Vaultwarden.
  1. **Network**: AdGuard Home, SearXNG.
- **Widgets**: Real-time CPU, RAM, and root filesystem disk utilization monitors, plus an integrated search bar pointing to SearXNG.

### 2.2 SearXNG ("yi search") (`modules/services/searxng.nix`)

- **Web UI**: Binds all interfaces (`0.0.0.0:24888`, not loopback — the Firecrawl container reaches it via `host.containers.internal`) and is proxied to `https://searxng.aset.love` through the local ingress. The firewall scopes the exposure: `eno1` admits only declared ports plus the `yirukou` gateway (which reaches the local ingress and Loki, not SearXNG directly), `tailscale0` only SSH and DNS, and an explicit input rule admits the application-container subnets to the SearXNG port.
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

- **Web UI**: Bound to loopback (`listen = false`, `whitelistMode = false`) behind the local ingress and proxied to `https://sillytavern.aset.love` with `hostWhitelist` pinned to `sillytavern.aset.love` and `minLogLevel = 1` (`INFO`) to keep prompt/reply debug payloads out of journald/Loki.
- **Security Context**: Dedicated non-root user `sillytavern` with strict systemd filesystem isolation (`ProtectSystem = strict`, `ProtectHome = true`, `PrivateDevices = true`, `PrivateTmp = true`, `StateDirectoryMode = "0700"`, `UMask = "0077"`, `0700` data dir, `0600` config/settings).
- **Inference Integration**: Ordered after the local `llama-cpp.service` Vulkan router; a `pkgs.formats.yaml` `config.yaml` + an idempotent startup `settings.json` overlay derived from `models.nix` and `hosts.nix` provision all four uncensored LLM Connection Manager profiles (`yifuwuqi / deepseek-v4-pro-qwen3.5-9b-uncensored`, `yifuwuqi / gemma-4-12b-uncensored` default at `http://127.0.0.1:11436/v1`, `yitaishi / gemma-4-26b-a4b-uncensored`, and `yitaishi / qwen3.8-27b-uncensored` at `http://100.69.0.4:11436/v1`, `media_inlining = false`) and `yitaishi` `sdcpp` (`http://100.69.0.4:11437`, `chroma1-hd`).

### 2.6 Cockpit System Manager (`modules/services/cockpit.nix`)

- **Web UI**: Port `24091` (`https://cockpit.aset.love`), with the file manager at `https://cockpit.aset.love/files`.
- **Configuration**: Configured with `WebService.AllowUnencrypted = true`, `ProtocolHeader = "X-Forwarded-Proto"`, and `ForwardedForHeader = "X-Forwarded-For"` to work behind Nginx TLS termination (`longTimeouts` and `proxy_buffering off` in `modules/services/proxy-vhosts.nix`), with explicit origin allowlisting across LAN, local hostname, and FQDN. Includes `pkgs.sysstat` for historical performance graphing. The Kernel dump page is hidden (`/etc/xdg/cockpit/kdump.override.json`, matching `XDG_CONFIG_DIRS=/etc/xdg:...`): NixOS `kexec` is for fast reboot, not Fedora's `kdump.service`, and that page only shows a false "install kexec-tools" alert.
- **Plugins**: `cockpit-podman` (Podman containers, replaces the former Portainer CE deployment; PAM login), `cockpit-files` (web file manager for browsing, editing, uploading, and downloading files), `cockpit-dockermanager`, `cockpit-machines` (libvirt UI), `cockpit-zfs` (ZFS UI). The last two only add the pages; libvirt and ZFS are not enabled on this host.

### 2.7 WebDAV Server (`modules/services/webdav.nix`, dormant)

- **Status**: Disabled (commented out in `hosts/yifuwuqi/services.nix` and absent from the active registry directory above).
- **Configuration**: Built using `pkgs.nginxModules.dav` (`https://webdav.aset.love`), root directory `/srv/webdav` (mode 0775, `nginx:nginx`), unlimited client max body size (`client_max_body_size 0`), support for all standard WebDAV methods (`PUT`, `DELETE`, `MKCOL`, `COPY`, `MOVE`, `PROPFIND`, `OPTIONS`, `LOCK`, `UNLOCK`).

### 2.8 Gang Documentation (`docs/service.nix`)

- **Web UI**: Bound to loopback behind the local ingress and proxied to `https://docs.aset.love`.
- **Real-Time Auto-Builder**: Watchexec monitors `/home/yi/the.files/nixos/docs` on `yifuwuqi` (debounced by 1500ms).
- **Out-of-Tree RAM Staging**: Copies the bind-mounted `docs/` tree into a `mktemp` directory and dynamically appends the `# Architecture Plans & RFCs` navigation from `src/plans/*.md` there, without modifying the git repository.
- **Serving Daemon**: `darkhttpd` serves `/var/lib/gang-docs/book` as the dedicated `docs` system user with strong systemd sandboxing (`ProtectHome = true`, `SystemCallFilter = [...]`).

### 2.9 Authelia (`modules/services/authelia.nix`)

- **Role**: The one login for every gated vhost. `yirukou` asks its AuthRequest endpoint before proxying ([the gate](dns-and-proxy.md#221-authelia-gate-forward-auth)); the portal itself is `https://authelia.aset.love`, outside the gate.
- **Identity**: A declarative file backend rendered from a sops template (`services/authelia/users/yi` holds the argon2id digest), so password reset and change are disabled and passwords change in sops. Every gated host requires password + TOTP (`access_control.default_policy = two_factor`).
- **TOTP enrolment**: The filesystem notifier writes the one-time confirmation code to `/var/lib/authelia/notification.txt` (read it as root).
- **Storage**: PostgreSQL over the unix socket with peer auth: the unsuffixed instance runs as `authelia`, the role `pgDatabases` creates, so no database password exists. `services/authelia/storage-encryption-key` encrypts the TOTP secrets at rest. Session state is in-process (no Redis), so a restart logs everyone out.
- **Backups**: `postgresqlBackup-authelia` dumps the database to `/var/backup/postgresql/authelia.sql.gz` on the `backups` maintenance slot; TOTP enrolments are the only state config cannot recreate.

### 2.10 Vaultwarden (`modules/services/vaultwarden.nix`)

- **Role**: The human credential store (Bitwarden-compatible). SOPS stays machine-facing; people read and write through Bitwarden clients at `https://vaultwarden.aset.love`.
- **Gate**: Exempt, because Bitwarden clients call the identity and sync APIs directly and the vault's master-password login is stronger than the gate. Signups are closed; invite accounts from `/admin` with the `tokens/vaultwarden-admin` token.
- **Storage**: PostgreSQL over the unix socket with peer auth (`vaultwarden` role and service account), loopback `127.0.0.1:24150`.
- **Backups**: `postgresqlBackup-vaultwarden` dumps the database to `/var/backup/postgresql/vaultwarden.sql.gz`, and `backup-vaultwarden-data` archives the data folder (attachments, sends, the token-signing key) to `/var/backup/vaultwarden/data.tar.gz`. A restore needs both.

______________________________________________________________________

## 3. Key Source Files

- `docs/service.nix`
- `modules/services/authelia.nix`
- `modules/services/vaultwarden.nix`
- `modules/services/homepage.nix`
- `modules/services/searxng.nix`
- `modules/services/valkey.nix`
- `modules/services/firecrawl.nix`
- `modules/services/ai/sillytavern.nix`
- `modules/services/cockpit.nix`
- `modules/services/webdav.nix`
- `hosts/yifuwuqi/services.nix`
