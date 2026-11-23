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
│  │ (1gb, local only)     │  ││  │ (512mb, local only)   │  │
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
  - `Hagezi Multi PRO` (Tracker & malware protection; `Hagezi Multi PRO++` stays defined but disabled)
  - `Hagezi TIF` (Threat Intelligence Feeds)
  - Custom rules: `||api.miwifi.com^`
- **DNS Rewrites**:
  - `*.aset.love` $\\to$ `10.42.0.1` (Points all subdomains to `yirukou` reverse proxy)
  - `smb.aset.love` $\\to$ `10.42.0.2` (Points SMB file share directly to `yifuwuqi`)
  - `ssh.aset.love` $\\to$ `10.42.0.2` (Plain SSH to `yifuwuqi` on `24212` over the LAN and the Tailnet subnet route; the Cloudflare tunnel is `cloudflare.aset.love`)
  - Dynamic host rewrites generated for `.lan`/`.local`/`.ts` aliases. `.lan` and `.local` answer both A and AAAA (the LAN ULA), so internal names are reached over IPv6; `.ts` and the `aset.love` wildcards stay IPv4-only because nginx and its backends stay on IPv4.
  - Optional private rewrites from `/persist/keys/adguardhome/rewrites.yaml` (`0640 root:nginx` inside `0750 root:nginx` on `yirukou`): YAML list of `{ domain, answer, enabled? }` entries (e.g. `- domain: local.work.com` / `answer: 10.42.0.2`; `enabled` defaults to `true`) appended in `adguardhome` `preStart` via `yq-go`, keeping private hostnames out of git, `/nix/store`, and SOPS. Restart `adguardhome` after editing.
- **Encrypted DNS Endpoints**:
  - DNS-over-TLS (DoT): Port `853` on `dns.aset.love` (manual clients; AGH DDR omits DoT without IP SANs on the ACME cert)
  - DNS-over-QUIC (DoQ): Port `853` on `dns.aset.love`
  - DNS-over-HTTPS (DoH): Port `3443` (what DDR advertises) and nginx `https://dns.aset.love/dns-query` on 443
- **DDR**: `dns.handle_ddr = true`. AGH answers SVCB for `_dns.resolver.arpa` with target `dns.aset.love` (DoH `:3443`, DoQ `:853`). The `:53` intercept still delivers those queries to AGH. Unbound does not serve this name. There is no DNR (Kea stays DHCPv4-only; RA is RDNSS only).
- **Upstream Forwarding**: Queries prefer local Unbound at `[::1]:5335` with
  `127.0.0.1:5335` retained as fallback. Bootstrap and local PTR upstreams list
  IPv6 first with `bootstrap_prefer_ipv6 = false`, and `ipv6_disabled` stays
  false so ULA AAAA answers work.
- **Blocking**: Custom-IP blocking returns RFC 7534 AS112 `192.175.48.1` for A
  and `2620:4f:8000::1` for AAAA. Only yirukou assigns the sinkhole addresses
  on `br0`; both AdGuard instances return them. Clients hold no IPv6 default
  route, so the blocked AAAA is unreachable and fails immediately without a
  round trip.

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

`yirukou` serves as the central reverse proxy for the entire infrastructure. It terminates TLS and forwards services hosted on `yifuwuqi` to one local ingress listener, which routes on the preserved `Host` header to the loopback backend. One canonical service list in `modules/services/proxy-vhosts.nix` generates both proxy hops. Services on other mesh hosts use explicit Tailscale upstreams.

```text
┌─────────────────────────────────────────────────────────────┐
│                    Nginx Ingress (yirukou)                  │
├─────────────────────────────────────────────────────────────┤
│ • Wildcard ACME TLS (*.aset.love via Cloudflare DNS-01)     │
│ • Zero-Trust ACL: LAN (10.42.0.0/24) + VPN CIDRs allowed    │
├──────────────────────────────┬──────────────────────────────┤
│ Virtual Host                 │ Backend Destination          │
├──────────────────────────────┼──────────────────────────────┤
│ adguard.aset.love            │ 127.0.0.1:3333 (Local)       │
│ dns.aset.love                │ 127.0.0.1:3333/dns-query     │
│ goaccess.aset.love           │ /var/lib/goaccess + :7890 ws │
├──────────────────────────────┼──────────────────────────────┤
│ docs / grafana / cockpit /   │ 10.42.0.2:24120 (yifuwuqi    │
│ search / cache / git / agent │ local ingress, mTLS;         │
│ / companion / home / radarr  │ routes on Host to loopback)  │
│ / sonarr / prowlarr / ...    │                              │
│ image.aset.love              │ 100.69.0.4:11437 (yitaishi)  │
└──────────────────────────────┴──────────────────────────────┘
```

`yifuwuqi`'s local ingress (`modules/services/local-ingress.nix`) is one nginx listener on the LAN address, port `24120` (`services.ingress.port`). It has one vhost per proxied domain pointing at the loopback backend (a few that cannot bind loopback — jellyfin, jellyseerr, homepage, lidarr — keep the LAN address, `upstreamLan`), and rejects unknown `Host` headers with `404`. Only `yirukou` may reach it (the `yifuwuqi` firewall allows the gateway only `24120`; the vhosts also `allow`/`deny`). It preserves the real client IP, scheme, and host from `yirukou`'s `X-Forwarded-*`/`X-Real-IP` headers.

`image.aset.love` bypasses the `yifuwuqi` ingress because its backend runs on `yitaishi`; yirukou proxies directly to the backend's Tailscale-only listener.

### 2.1 Automated ACME Wildcard Certificates

- Managed via `security.acme` using Cloudflare DNS-01 API challenges.
- Certificate `aset.love` covers both apex `aset.love` and wildcard `*.aset.love`.
- Authenticates using `cloudflare_api_token` managed by Sops-nix.

### 2.2 Access Control & Security

- `restrictedProxyConfig`: Injects explicit CIDR allow directives for the trusted LAN (IPv4 `10.42.0.0/24` and IPv6 `fd75:c55f:6d19:1::/64`), followed by `deny all;`. Enforced across all internal reverse-proxied virtual hosts on `yirukou` to ensure untrusted VLAN, overlay, and external networks cannot reach the proxy. Tailnet clients reach them through `yirukou`'s subnet route, SNAT'd to `10.42.0.1`. On `yifuwuqi` the local-ingress vhosts independently `allow` only `yirukou`'s LAN address (`10.42.0.1`) and `deny all`, so a direct peer that bypasses the gateway gets no backend access.
- WebSocket proxying (`proxy_set_header Upgrade $http_upgrade;`, `proxy_set_header Connection "upgrade";`) enabled per-service on both hops (defaults on; disabled for attic, docs, forgejo, and searxng which do not use WebSockets).

### 2.3 Inter-Host mTLS

Every hop between `yirukou` and `yifuwuqi` is mutual TLS on that one ingress port, using `service-ca` and per-host leaves (`modules/services/mtls.nix`). The material — CA cert plus each host's own server and client pair — lives in `/persist/keys/mtls/` as `0640 root:mtls` in a `0750 root:mtls` directory: not in git, not in the Nix store, not a sops secret. Nix names the paths; nginx, Prometheus and Vector join the `mtls` group to read them.

- `yirukou` proxies each application domain to `https://10.42.0.2:24120` with `proxy_ssl_verify on`, presenting `yirukou-client`.
- The `yifuwuqi` vhosts require a client certificate **and** pin the subject: `if ($ssl_client_s_dn != "CN=yirukou-client") { return 403; }`. Chain validation alone would admit either host's certificate.
- Upstreams name the peer (`proxy_ssl_name <peer>.lan`) rather than the IP: nginx matches with `X509_check_host()`, which never matches an `IP:` SAN.
- The default vhost on each listener carries the machine paths. Prometheus and Vector cannot set `Host`, so they land there: `/<exporter>/` and, on `yifuwuqi`, `/loki/`. Those locations allow only the addresses that may connect and require a client certificate, but pin no subject — their callers are the scrape and log shippers.
- Minting and distribution are in [secrets.md](secrets.md#internal-service-mtls-certificates); there is no per-host enrolment step.

______________________________________________________________________

## 3. Key Source Files

- `modules/services/adguardhome.nix`
- `modules/services/unbound.nix`
- `modules/services/valkey.nix`
- `modules/services/nginx-proxy.nix`
- `modules/services/proxy-vhosts.nix`
- `modules/services/local-ingress.nix`
- `modules/services/cloudflared.nix`
- `modules/addresses.nix`
