# Unbound Recursive Resolver & L2 Cache Architecture

This document describes the active architecture and operational management of the Unbound recursive DNS resolver and its integration with AdGuard Home and Valkey.

______________________________________________________________________

## 1. Active Architecture

```text
Client (LAN / Mesh)
  │ Port 53 (UDP/TCP)
  ▼
AdGuard Home (:53)
  ├── 1. Matches against Hagezi blocklists & local .fufu.land rewrites
  ├── 2. Answers immediately from 64MB optimistic RAM cache if hot
  └── 3. If unblocked & cold: forwards to [::1]:5335
        (127.0.0.1:5335 fallback)
        │
        ▼
Unbound Recursive Resolver ([::1]:5335 + 127.0.0.1:5335)
  ├── 1. Inspects local memory RRset / message cache
  ├── 2. Queries host-local Valkey L2 Cache (/run/redis/redis.sock)
  │      └── Each host owns its own L2 database; nothing crosses the LAN
  └── 3. If cold across all caches: performs recursive root lookup
         └── Returns answer to AdGuard Home & saves to Valkey L2
```

______________________________________________________________________

## 2. Configuration & Module Features (`modules/services/unbound.nix`)

- **Binding**: Listens on `[::1]:5335` and `127.0.0.1:5335`, with loopback-only ACLs. AdGuard prefers IPv6 and uses IPv4 as fallback.
- **Host-local Valkey L2 Cache**: Configured via `cachedb` module (`module-config: "validator cachedb iterator"`):
  - Backend: `cachedb-backend: "redis"`
  - Server: `redis-server-path: /run/redis/redis.sock` — the unix socket of the
    valkey instance on the *same* host. No TCP, no LAN.
  - `redis-timeout: 100` (ms)
  - The cache is deliberately **not** shared between hosts. `cachedb` talks to
    redis synchronously and the thread waiting on it cannot serve other DNS
    queries, so upstream warns that frequent timeouts make Unbound "effectively
    unusable with this backend" (`unbound.conf(5)`, cachedb section). Pointing
    one host's cachedb at another host's LAN address stalled the resolver
    whenever that link dropped, which is why each host now owns its instance.
- **Stale-While-Revalidate (SWR)**:
  - `serve-expired = "yes"`
  - `serve-expired-ttl = 86400` (1 day max stale serving window)
  - `serve-expired-reply-ttl = 30` (returns 30s TTL to client while refreshing)
  - `prefetch = "yes"` (refreshes popular expiring domains automatically)
- **Privacy & DNSSEC**:
  - `qname-minimisation = "yes"` (only sends the necessary domain segment to root/TLD servers)
  - `hide-identity = "yes"`, `hide-version = "yes"`
  - `harden-glue = "yes"`, `harden-dnssec-stripped = "yes"`
- **Control Socket**: Local control socket enabled at `/run/unbound/unbound.ctl`.

______________________________________________________________________

## 3. Operational Inspection & Diagnostics

Because `localControlSocketPath` is active, administrators can query Unbound directly on the host using `unbound-control`:

### 3.1 Inspecting Running Status & Statistics

```bash
sudo unbound-control -c /etc/unbound/unbound.conf status
sudo unbound-control -c /etc/unbound/unbound.conf stats_noreset
```

### 3.2 Dumping the Cache

```bash
sudo unbound-control -c /etc/unbound/unbound.conf dump_cache
```

### 3.3 Flushing Specific Domains or Entire Zones

```bash
# Flush a single domain
sudo unbound-control -c /etc/unbound/unbound.conf flush github.com

# Flush an entire zone
sudo unbound-control -c /etc/unbound/unbound.conf flush_zone .
```

______________________________________________________________________

## 4. Key Source Files

- `modules/services/unbound.nix`
- `modules/services/adguardhome.nix`
- `modules/services/valkey.nix`
- `hosts/yirukou/services.nix`
- `hosts/yifuwuqi/services.nix`
