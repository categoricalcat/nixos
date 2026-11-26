# DNS and Reverse Proxy Infrastructure

The homelab runs a dual-host recursive DNS pipeline and an Nginx reverse proxy infrastructure that terminates TLS, enforces zero-trust IP allowlists, and routes traffic to backend daemons.

______________________________________________________________________

## 1. DNS Architecture

One recursive pipeline, on `yirukou`, and one stub that forwards to it.

```text
┌─────────────────────────────────────────────────────────────┐
│                    LAN & Mesh Clients                       │
└──────────┬───────────────────────────────────┬──────────────┘
           │ Query (DHCP: 10.42.0.1,           │ Query (DHCP: 10.42.0.2,
           │ RDNSS fd75:c55f:6d19:1::1)        │ RDNSS fd75:c55f:6d19:1::2)
           │                                   ▼
           │                    ┌─────────────────────────────┐
           │                    │  yifuwuqi systemd-resolved  │
           │                    │  stub :53, Cache = "no"     │
           │                    └──────────────┬──────────────┘
           │                          DoT :853 │ #dns.aset.love
           ▼                                   ▼
┌─────────────────────────────────────────────────────────────┐
│                      yirukou DNS Node                       │
│  ┌───────────────────────┐                                  │
│  │ AdGuard Home (:53)    │                                  │
│  │ 64MB Cache, Hagezi    │                                  │
│  │ Local DNS Rewrites    │                                  │
│  └───────────┬───────────┘                                  │
│              │ [::1]:5335                                    │
│  ┌───────────▼───────────┐                                  │
│  │ Unbound Resolver      │                                  │
│  │ (Recursive DNS)       │                                  │
│  └───────────┬───────────┘                                  │
│              │ unix socket                                   │
│  ┌───────────▼───────────┐                                  │
│  │ Valkey L2 Cache       │                                  │
│  │ (1gb, local only)     │                                  │
│  └───────────────────────┘                                  │
└─────────────────────────────────────────────────────────────┘
```

Only `yirukou` runs AdGuard Home and Unbound (`modules/services/adguardhome.nix`,
`modules/services/unbound.nix`); it is the LAN's recursive resolver. Kea DHCP
still hands out both `10.42.0.1` and `10.42.0.2`, and RA RDNSS both ULAs, so
clients keep a second address to try — but the second address is now
`yifuwuqi`'s `systemd-resolved` stub, which answers no query locally and
forwards every one of them to `yirukou`'s AdGuard over DNS-over-TLS. The stub is
the whole of `yifuwuqi`'s resolver: no AdGuard, no Unbound, no cache.

Local DNS is dual-stack over the LAN ULA with IPv6 preferred and IPv4 kept as
fallback everywhere: host resolvers list the ULA or `::1` before IPv4, and
AdGuard reaches Unbound over `[::1]:5335` before `127.0.0.1:5335`. Nothing here
depends on public IPv6 — there is no IPv6 default route or egress, so public
domains and all proxy/backend traffic are contacted over IPv4. Background:
[IPv6 ULA vs GUA](../networking/ipv6-ula-gua.md).

The stub is a single encrypted hop, not a second cache. `yifuwuqi` never
resolves anything on its own behalf either: `eno1` carries `Domains = ~.` and
the two DoT upstreams, while `enp4s0` runs `UseDNS = false`, `tailscale0` runs
with `acceptDns = false`, and `FallbackDNS` is empty. Losing `eno1` therefore
leaves that host with no resolver at all rather than a silent plaintext one;
the `resolver-path` contract in `nix/checks.nix` pins all three.

### 1.1 AdGuard Home (The Edge Filter)

- **Binding**: `yirukou` binds explicit addresses; the `::` wildcard is gone.
  Because the RDNSS targets are now static ULAs instead of rotating link-local
  addresses, `yirukou` can list them directly: `::1`, `fd75:c55f:6d19:1::1`,
  `fd75:c55f:6d19:2::1`, `127.0.0.1`, `10.42.0.1`, and its Tailscale address.
  It also binds VLAN 42's `10.42.42.1` for DHCPv4 clients.
  No listener binds a WAN address. Web management is IPv4 on port `3333`.
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
  on `br0`. Clients hold no IPv6 default route, so the blocked AAAA is
  unreachable and fails immediately without a round trip.

### 1.2 Unbound (The Recursive Root Resolver)

- **Binding**: Listens on `127.0.0.1:5335` and `[::1]:5335`; ACLs allow only
  IPv4 and IPv6 loopback.
- **Transport**: `do-ip6` stays `yes` because disabling it would also remove
  the `::1` listener AdGuard uses. Iteration to the internet is IPv4 in
  practice, since `yirukou` has no IPv6 default route.
- **Host-local Valkey L2 Cache**: Configured with `module-config: "validator cachedb iterator"`. `yirukou` runs its own Valkey and reaches it over the unix socket `/run/redis/redis.sock`; the cache survives Unbound restarts and reboots via RDB snapshots. It is never shared across the LAN: `cachedb` is synchronous, and the thread waiting on redis cannot serve other DNS queries, so upstream warns that frequent timeouts make Unbound "effectively unusable with this backend". A shared instance meant the resolver stalled whenever the link to the cache host dropped.
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
│ adguardhome.aset.love        │ 127.0.0.1:3333 (Local)       │
│ dns.aset.love                │ 127.0.0.1:3333/dns-query     │
│ goaccess.aset.love           │ /var/lib/goaccess + :7890 ws │
├──────────────────────────────┼──────────────────────────────┤
│ docs / grafana / cockpit /   │ 10.42.0.2:24120 (yifuwuqi    │
│ searxng / attic / forgejo /  │ local ingress, mTLS;         │
│ opencode / sillytavern /     │ routes on Host to loopback)  │
│ homepage / authelia / ...    │                              │
│ sd-cpp.aset.love             │ 100.69.0.4:11437 (yitaishi)  │
└──────────────────────────────┴──────────────────────────────┘
```

Every service hostname is its registry key (`<key>.aset.love`); the `vhost-naming` contract in `nix/checks.nix` rejects nicknames.

A catch-all vhost (`server_name _;`, `default_server` on 443 and the port-80 redirect listener) answers unmatched `Host` headers with `404 unknown host`. Without it, nginx falls back to the alphabetically-first vhost (`adguardhome.aset.love`) and unknown subdomains render the AdGuard UI.

`yifuwuqi`'s local ingress (`modules/services/local-ingress.nix`) is one nginx listener on the LAN address, port `24120` (`services.ingress.port`). It has one vhost per proxied domain pointing at the loopback backend (a few that cannot bind loopback — jellyfin, jellyseerr, homepage, lidarr — keep the LAN address, `upstreamLan`), and rejects unknown `Host` headers with `404`. Only `yirukou` may reach it (the `yifuwuqi` firewall allows the gateway only `24120`; the vhosts also `allow`/`deny`). It preserves the real client IP, scheme, and host from `yirukou`'s `X-Forwarded-*`/`X-Real-IP` headers.

`sd-cpp.aset.love` bypasses the `yifuwuqi` ingress because its backend runs on `yitaishi`; yirukou proxies directly to the backend's Tailscale-only listener.

### 2.1 Automated ACME Wildcard Certificates

- Managed via `security.acme` using Cloudflare DNS-01 API challenges.
- Certificate `aset.love` covers both apex `aset.love` and wildcard `*.aset.love`.
- Authenticates using `cloudflare_api_token` managed by Sops-nix.

### 2.2 Access Control & Security

- `restrictedProxyConfig`: Injects explicit CIDR allow directives for the trusted LAN (IPv4 `10.42.0.0/24` and IPv6 `fd75:c55f:6d19:1::/64`), followed by `deny all;`. Enforced across all internal reverse-proxied virtual hosts on `yirukou` to ensure untrusted VLAN, overlay, and external networks cannot reach the proxy. Tailnet clients reach them through `yirukou`'s subnet route, SNAT'd to `10.42.0.1`. On `yifuwuqi` the local-ingress vhosts independently `allow` only `yirukou`'s LAN address (`10.42.0.1`) and `deny all`, so a direct peer that bypasses the gateway gets no backend access.
- WebSocket proxying (`proxy_set_header Upgrade $http_upgrade;`, `proxy_set_header Connection "upgrade";`) enabled per-service on both hops (defaults on; disabled for attic, docs, forgejo, and searxng which do not use WebSockets).

### 2.2.1 Authelia Gate (forward auth)

Inside the LAN allowlist, every browser-facing location on `yirukou` also asks Authelia before it proxies (`mkAuthGate` in `modules/services/proxy-vhosts.nix`). The gate is the only login for services without one of their own.

- Each gated location carries `auth_request /authelia-check;`. That internal location sends a body-less subrequest over the same mTLS hop to the `yifuwuqi` ingress with `Host: authelia.aset.love`, `X-Original-URL` and `X-Original-Method`, and Authelia's `/api/authz/auth-request` endpoint judges the session cookie. Client `Authorization` headers are dropped from the subrequest: they belong to the backend's protocol.
- `2xx` proxies the request with `Remote-User` set to the Authelia user. `401` becomes a `302` to the `Location` Authelia returns: the portal, with the original URL encoded in `rd`. Anything else, including Authelia being down, fails closed with `500`.
- One session cookie covers `aset.love`, so one login (password + TOTP; `access_control.default_policy = two_factor`) opens every gated host.
- Exemptions are named, never accidental: a `proxiedServices` entry carries an `authExempt` reason (`attic`, `authelia`, `jellyfin`, `pinepods`), and `dns.aset.love/dns-query` is a machine protocol. The `auth-gate` contract fails evaluation if any other served location lacks the gate, or if a gate's subrequest target is not that internal Authelia endpoint. Under any other `Host` the ingress would ask the backend itself, and a single-page app's catch-all `200` would admit every request.
- The `yifuwuqi` ingress is not gated a second time: it admits only the `yirukou-client` certificate, so every browser request already crossed the gate.
- Header logins: Grafana (`auth.proxy`) trusts `Remote-User` from the loopback ingress. Forgejo deliberately does not: its reverse-proxy auth trusts the header from any loopback client, so any local account on `yifuwuqi` could act as `yi`. It keeps its own login behind the gate until Authelia OIDC replaces it.
- OpenCode cannot run without a password, so the ingress presents it: `opencode-ingress-credential.service` renders `proxy_set_header Authorization "Basic …"` from `passwords/opencode` into `/run/opencode-ingress-credential/`, which the opencode location includes by glob.

### 2.3 Inter-Host mTLS

Every hop between `yirukou` and `yifuwuqi` is mutual TLS on that one ingress port, using `service-ca` and per-host leaves (`modules/services/mtls.nix`). The material — CA cert plus each host's own server and client pair — lives in `/persist/keys/mtls/` as `0640 root:mtls` in a `0750 root:mtls` directory: not in git, not in the Nix store, not a sops secret. Nix names the paths; nginx, Prometheus and Vector join the `mtls` group to read them.

- `yirukou` proxies each application domain to `https://10.42.0.2:24120` with `proxy_ssl_verify on`, presenting `yirukou-client`.
- The `yifuwuqi` vhosts require a client certificate **and** pin the subject: `if ($ssl_client_s_dn != "CN=yirukou-client") { return 403; }`. Chain validation alone would admit either host's certificate.
- Upstreams name the peer (`proxy_ssl_name <peer>.lan`) rather than the IP: nginx matches with `X509_check_host()`, which never matches an `IP:` SAN.
- The default vhost on each listener carries the machine paths. Prometheus and Vector cannot set `Host`, so they land there: `/<exporter>/` and, on `yifuwuqi`, `/loki/`. Those locations allow only the addresses that may connect and require a client certificate, but pin no subject — their callers are the scrape and log shippers.
- Minting and distribution are in [secrets.md](secrets.md#internal-service-mtls-certificates); there is no per-host enrolment step.

#### The one hop that is not mTLS

`systemd-resolved` has no client-certificate option at all, so the resolver hop cannot be mutual. `yifuwuqi`'s stub reaches `yirukou`'s AdGuard DoT listener on `:853` with `DNSOverTLS = "yes"` and the name `dns.aset.love`: server-authenticated TLS, verified against the `aset.love` ACME wildcard rather than `service-ca`. That is the only inter-host flow that does not terminate at nginx, and it is an exception recorded here rather than an unstated gap. What it does not change: `:53` and `:853` stay open to LAN and VLAN 42 clients, so the certificate is relay authentication, not admission control — AdGuard's `bind_hosts` and the interface firewall are.

#### Egress allowlist, log-only

`modules/services/mtls.nix` also emits an `mtls-peer` nftables table on both hosts. It matches locally generated packets destined to a peer address and, for a new connection outside the allowlist, logs `mtls-peer:` at warn and accepts. It never rejects: admission is already enforced by the peer certificates, the per-location nginx allowlists and the per-interface firewall, and the output hook cannot tell a Tailnet client's forwarded traffic from the host's own. The allowlist is derived from the same registry as the ingress port, so a new flow shows up in `journalctl -k --grep mtls-peer` instead of failing silently. SSH, ICMP and WireGuard are the enumerated exceptions; see [sysctl-firewall.md](../networking/sysctl-firewall.md#inter-host-egress-allowlist).

______________________________________________________________________

## 3. Key Source Files

- `modules/services/adguardhome.nix`
- `modules/services/unbound.nix`
- `modules/services/valkey.nix`
- `modules/services/nginx-proxy.nix`
- `modules/services/proxy-vhosts.nix`
- `modules/services/local-ingress.nix`
- `modules/services/authelia.nix`
- `modules/services/cloudflared.nix`
- `modules/addresses.nix`
