# DNS and Reverse Proxy Infrastructure

The homelab runs a dual-host recursive DNS pipeline and an Nginx reverse proxy infrastructure that terminates TLS, enforces zero-trust IP allowlists, and routes traffic to backend daemons.

______________________________________________________________________

## 1. Dual DNS Pipeline Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                    LAN & Mesh Clients                       │
└──────────────┬──────────────────────────────┬───────────────┘
               │ Query (DHCP: 10.42.0.1)      │ Query (DHCP: 10.42.0.2)
               ▼                              ▼
┌─────────────────────────────┐┌─────────────────────────────┐
│      yirukou DNS Node       ││      yifuwuqi DNS Node      │
│  ┌───────────────────────┐  ││  ┌───────────────────────┐  │
│  │ AdGuard Home (:53)    │  ││  │ AdGuard Home (:53)    │  │
│  │ 64MB Cache, Hagezi    │  ││  │ 64MB Cache, Hagezi    │  │
│  │ Local DNS Rewrites    │  ││  │ Local DNS Rewrites    │  │
│  └───────────┬───────────┘  ││  └───────────┬───────────┘  │
│              │ 127.0.0.1:5335│              │ 127.0.0.1:5335
│  ┌───────────▼───────────┐  ││  ┌───────────▼───────────┐  │
│  │ Unbound Resolver      │  ││  │ Unbound Resolver      │  │
│  │ (Recursive DNS)       │  ││  │ (Recursive DNS)       │  │
│  └───────────┬───────────┘  ││  └───────────┬───────────┘  │
└──────────────┼──────────────┘└──────────────┼──────────────┘
               │                              │
               │ L2 Cache (10.42.0.2:6379)    │ L2 Cache (Local Socket/LAN)
               ▼                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 Valkey Shared L2 DNS Cache                  │
│                     (on yifuwuqi:6379)                      │
└─────────────────────────────────────────────────────────────┘
```

Both `yirukou` (router) and `yifuwuqi` (server) run identical, synchronized DNS modules (`modules/services/adguardhome.nix` and `modules/services/unbound.nix`). Kea DHCP distributes both IPs (`10.42.0.1` and `10.42.0.2`) to all network clients for seamless resolver redundancy.

### 1.1 AdGuard Home (The Edge Filter)

- **Binding**: Listens on `0.0.0.0:53` (Web management UI on port `3333`).
- **Memory Caching**: 64 MiB in-memory cache (`cache_enabled = true`, `cache_optimistic = true`, `cache_ttl_max = 300`) with `GOMEMLIMIT = 2560MiB`.
- **Filtering Blocklists**:
  - `Hagezi Multi PRO++` (Comprehensive tracker & malware protection)
  - `Hagezi TIF` (Threat Intelligence Feeds)
  - Custom rules: `||api.miwifi.com^`
- **DNS Rewrites**:
  - `*.fufu.land` $\\to$ `10.42.0.1` (Points all subdomains to `yirukou` reverse proxy)
  - `smb.fufu.land` $\\to$ `10.42.0.2` (Points SMB file share directly to `yifuwuqi`)
  - Dynamic host rewrites generated for all bare machine names and `.lan`/`.local`/`.ts`/`.nb` aliases.
- **Encrypted DNS Endpoints**:
  - DNS-over-TLS (DoT): Port `853` on `dns.fufu.land`
  - DNS-over-QUIC (DoQ): Port `853` on `dns.fufu.land`
  - DNS-over-HTTPS (DoH): Port `3443` and HTTPS reverse proxy endpoint `https://dns.fufu.land/dns-query`
- **Upstream Forwarding**: All non-blocked queries are forwarded to the local Unbound instance at `127.0.0.1:5335`.

### 1.2 Unbound (The Recursive Root Resolver)

- **Binding**: Listens on `127.0.0.1:5335` (`access-control = [ "127.0.0.0/8 allow" ]`).
- **Shared Valkey L2 Cache**: Configured with `module-config: "validator cachedb iterator"`. Connects to the centralized Valkey instance on `yifuwuqi` (`10.42.0.2:6379`). Both hosts share identical cached DNS records across reboots.
- **Stale-While-Revalidate (SWR)**: `serve-expired = "yes"`, `serve-expired-ttl = 86400`, `serve-expired-reply-ttl = 30` ensures queries are answered immediately from cache while background tasks revalidate expiring records.
- **Control Socket & Metrics**: Control socket `/run/unbound/unbound.ctl` allows CLI inspection via `unbound-control` and feeds the Prometheus `unbound-exporter` with extended metrics.

______________________________________________________________________

## 2. Nginx Ingress Reverse Proxy (`modules/services/nginx-proxy.nix`)

`yirukou` serves as the central reverse proxy for the entire infrastructure.

```text
┌─────────────────────────────────────────────────────────────┐
│                    Nginx Ingress (yirukou)                  │
├─────────────────────────────────────────────────────────────┤
│ • Wildcard ACME TLS (*.fufu.land via Cloudflare DNS-01)     │
│ • Zero-Trust ACL: LAN (10.42.0.0/24) + VPN CIDRs allowed    │
├──────────────────────────────┬──────────────────────────────┤
│ Virtual Host                 │ Backend Destination          │
├──────────────────────────────┼──────────────────────────────┤
│ adguard.fufu.land            │ 127.0.0.1:3333 (Local)       │
│ dns.fufu.land                │ 127.0.0.1:3333/dns-query     │
│ docs.fufu.land               │ /var/lib/docs (mdBook)       │
│ goaccess.fufu.land           │ /var/lib/goaccess + :7890 ws │
├──────────────────────────────┼──────────────────────────────┤
│ grafana.fufu.land            │ 10.42.0.2:3000 (yifuwuqi)    │
│ cockpit.fufu.land            │ 10.42.0.2:9090 (yifuwuqi)    │
│ search.fufu.land             │ 10.42.0.2:8888 (yifuwuqi)    │
│ attic.fufu.land              │ 10.42.0.2:18203 (yifuwuqi)   │
│ git.fufu.land (Forgejo)      │ 10.42.0.2:3001 (yifuwuqi)    │
│ prtnr.fufu.land (Portainer)  │ 10.42.0.2:9443 (yifuwuqi)    │
│ agent.fufu.land (Opencode)   │ 10.42.0.2:3010 (yifuwuqi)    │
│ sillytavern.fufu.land        │ 10.42.0.2:8000 (yifuwuqi)    │
│ homepage.fufu.land           │ 10.42.0.2:8082 (yifuwuqi)    │
│ radarr / sonarr / prowlarr...│ 10.42.0.2:7878/8989... (Arr) │
└──────────────────────────────┴──────────────────────────────┘
```

### 2.1 Automated ACME Wildcard Certificates

- Managed via `security.acme` using Cloudflare DNS-01 API challenges.
- Certificate `fufu.land` covers both apex `fufu.land` and wildcard `*.fufu.land`.
- Authenticates using `cloudflare_api_token` managed by Sops-nix.

### 2.2 Access Control & Security

- `restrictedProxyConfig`: Injects explicit CIDR allow directives for the trusted LAN (`10.42.0.0/24`) and Tailscale/NetBird VPNs, followed by `deny all;`.
- WebSocket proxying (`proxy_set_header Upgrade $http_upgrade;`, `proxy_set_header Connection "upgrade";`) enabled for Grafana, Cockpit, GoAccess, SillyTavern, and Arr apps.

______________________________________________________________________

## 3. Key Source Files

- `modules/services/adguardhome.nix`
- `modules/services/unbound.nix`
- `modules/services/valkey.nix`
- `modules/services/nginx-proxy.nix`
- `modules/services/cloudflared.nix`
- `modules/addresses.nix`
