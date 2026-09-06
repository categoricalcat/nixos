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
│              │ [::1]:5335    │              │ [::1]:5335
│  ┌───────────▼───────────┐  ││  ┌───────────▼───────────┐  │
│  │ Unbound Resolver      │  ││  │ Unbound Resolver      │  │
│  │ (Recursive DNS)       │  ││  │ (Recursive DNS)       │  │
│  └───────────┬───────────┘  ││  └───────────┬───────────┘  │
│              │ unix socket   │              │ unix socket
│  ┌───────────▼───────────┐  ││  ┌───────────▼───────────┐  │
│  │ Valkey L2 Cache       │  ││  │ Valkey L2 Cache       │  │
│  │ (512mb, local only)   │  ││  │ (1gb, local only)     │  │
│  └───────────────────────┘  ││  └───────────────────────┘  │
└─────────────────────────────┘└─────────────────────────────┘
```

Both `yirukou` (router) and `yifuwuqi` (server) run identical, synchronized DNS modules (`modules/services/adguardhome.nix` and `modules/services/unbound.nix`). Kea DHCP distributes both IPs (`10.42.0.1` and `10.42.0.2`) to all network clients for seamless resolver redundancy; IPv6 clients receive `fd75:c55f:6d19:1::1` (or `fd75:c55f:6d19:2::1` on VLAN 42) through RA RDNSS, since there is no DHCPv6 server.

Local DNS is dual-stack over the LAN ULA with IPv6 preferred and IPv4 kept as
fallback everywhere: host resolvers list the ULA or `::1` before IPv4, and
AdGuard reaches Unbound over `[::1]:5335` before `127.0.0.1:5335`. Nothing here
depends on public IPv6 — there is no IPv6 default route or egress, so public
domains and all proxy/backend traffic are contacted over IPv4. Background:
[IPv6 ULA vs GUA](../networking/ipv6-ula-gua.md).

### 1.1 AdGuard Home (The Edge Filter)

- **Binding**: both hosts bind explicit addresses; the `::` wildcard is gone.
  Because the RDNSS targets are now static ULAs instead of rotating link-local
  addresses, `yirukou` can list them directly: `::1`, `fd75:c55f:6d19:1::1`,
  `fd75:c55f:6d19:2::1`, `127.0.0.1`, `10.42.0.1`, and its Tailscale address.
  It also binds VLAN 42's `10.42.42.1` for DHCPv4 clients.
  No listener binds a WAN address. `yifuwuqi` binds `::1`,
  `fd75:c55f:6d19:1::2`, and its IPv4 addresses, so it does not contend with
  aardvark-dns on the container bridges. Web management remains IPv4 on port
  `24333` on `yifuwuqi` and `3333` on `yirukou`.
- **Memory Caching**: 64 MiB in-memory cache (`cache_enabled = true`, `cache_optimistic = true`, `cache_ttl_max = 300`) with `GOMEMLIMIT = 2560MiB`.
- **Filtering Blocklists**:
  - `Hagezi Multi PRO++` (Comprehensive tracker & malware protection)
  - `Hagezi TIF` (Threat Intelligence Feeds)
  - Custom rules: `||api.miwifi.com^`
- **DNS Rewrites**:
  - `*.fufu.land` $\\to$ `10.42.0.1` (Points all subdomains to `yirukou` reverse proxy)
  - `smb.fufu.land` $\\to$ `10.42.0.2` (Points SMB file share directly to `yifuwuqi`)
  - Dynamic host rewrites generated for `.lan`/`.local`/`.ts`/`.nb` aliases. `.lan` and `.local` answer both A and AAAA (the LAN ULA), so internal names are reached over IPv6; `.ts`/`.nb` and the `fufu.land` wildcards stay IPv4-only because nginx and its backends stay on IPv4.
- **Encrypted DNS Endpoints**:
  - DNS-over-TLS (DoT): Port `853` on `dns.fufu.land` (manual clients; AGH DDR omits DoT without IP SANs on the ACME cert)
  - DNS-over-QUIC (DoQ): Port `853` on `dns.fufu.land`
  - DNS-over-HTTPS (DoH): Port `3443` (what DDR advertises) and nginx `https://dns.fufu.land/dns-query` on 443
- **DDR**: `dns.handle_ddr = true`. AGH answers SVCB for `_dns.resolver.arpa` with target `dns.fufu.land` (DoH `:3443`, DoQ `:853`). The `:53` intercept still delivers those queries to AGH. Unbound does not serve this name. There is no DNR (Kea stays DHCPv4-only; RA is RDNSS only).
- **Upstream Forwarding**: Queries prefer local Unbound at `[::1]:5335` with
  `127.0.0.1:5335` retained as fallback. Bootstrap and local PTR upstreams list
  IPv6 first with `bootstrap_prefer_ipv6 = false`, and `ipv6_disabled` stays
  false so ULA AAAA answers work.
- **Blocking**: Custom-IP blocking returns `10.42.0.24` for A and the
  static ULA `fd75:c55f:6d19::24` for AAAA. Only yirukou assigns the ULA;
  both AdGuard instances return it. Clients hold no IPv6 default route, so the
  blocked AAAA is unreachable and fails immediately without a round trip.

### 1.2 Unbound (The Recursive Root Resolver)

- **Binding**: Listens on `127.0.0.1:5335` and `[::1]:5335`; ACLs allow only
  IPv4 and IPv6 loopback.
- **Transport**: `do-ip6` stays `yes` because disabling it would also remove
  the `::1` listener AdGuard uses. Iteration to the internet is IPv4 in
  practice, since neither host has an IPv6 default route.
- **Host-local Valkey L2 Cache**: Configured with `module-config: "validator cachedb iterator"`. Each host runs its own Valkey and reaches it over the unix socket `/run/redis/redis.sock`; the cache survives Unbound restarts and reboots via RDB snapshots. The cache is intentionally not shared and never crosses the LAN: `cachedb` is synchronous, and the thread waiting on redis cannot serve other DNS queries, so upstream warns that frequent timeouts make Unbound "effectively unusable with this backend". A shared instance meant either resolver stalled whenever the link to the cache host dropped.
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
│ goaccess.fufu.land           │ /var/lib/goaccess + :7890 ws │
├──────────────────────────────┼──────────────────────────────┤
│ docs.fufu.land               │ 10.42.0.2:24083 (yifuwuqi)   │
│ grafana.fufu.land            │ 10.42.0.2:24030 (yifuwuqi)   │
│ cockpit.fufu.land            │ 10.42.0.2:24091 (yifuwuqi)   │
│ search.fufu.land             │ 10.42.0.2:24888 (yifuwuqi)   │
│ attic.fufu.land              │ 10.42.0.2:24203 (yifuwuqi)   │
│ git.fufu.land (Forgejo)      │ 10.42.0.2:24200 (yifuwuqi)   │
│ prtnr.fufu.land (Portainer)  │ 10.42.0.2:9443 (yifuwuqi)    │
│ agent.fufu.land (Opencode)   │ 10.42.0.2:24010 (yifuwuqi)   │
│ sillytavern.fufu.land        │ 10.42.0.2:24000 (yifuwuqi)   │
│ homepage.fufu.land           │ 10.42.0.2:24082 (yifuwuqi)   │
│ radarr / sonarr / prowlarr...│ 10.42.0.2:24878/24989...(Arr)│
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
