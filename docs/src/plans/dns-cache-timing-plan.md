# DNS Cache Timing/Size Sync Plan

## Objective

Layer AdGuard Home, Unbound, and Valkey so timings match roles:

- **AdGuard Home**: small, fast edge cache. Absorb LAN QPS, refresh Unbound often.
- **Unbound**: large long-term cache (100k+). Slow refresh, prefetch, serve-expired.
- **Valkey**: shared L2 for both Unbound instances. Redis `EX` matches Unbound's stale window; LRU only if memory fills.

Do not deploy in this document. Apply later; do not `nixos-rebuild`.

## Status: PLANNED — not applied. Fact-checked 2026-08-16

Snapshot 2026-08-16 on `yifuwuqi`. Mechanisms verified against source: unbound 1.25.2 (`cachedb/redis.c`, `cachedb/cachedb.c`, `util/data/msgreply.c`, `util/data/msgparse.h`), AGH 0.107.78 (`internal/dnsforward/config.go`), dnsproxy 0.83.0 (`proxy/cache.go`, `proxy/proxy.go`, `proxy/config.go`).

Topology: `yirukou` is the primary resolver, `yifuwuqi` secondary. Both hosts import `adguardhome.nix` + `unbound.nix`; `valkey.nix` only on `yifuwuqi` (central L2; valkey-guard nftables admits yirukou's unbound over LAN). Deploy targets both hosts.

## Current State

| Layer | Config | Live |
|-------|--------|------|
| AGH | 64 MiB, `cache_ttl_max=0`, optimistic 12h | inherits Unbound TTLs (1h–7d) |
| Unbound mem | msg 300m + rrset 600m; min 3600 / max 604800; serve-expired 7d | 201k msg, 374k rrset; ~203 MiB used |
| Valkey | 1 GiB `allkeys-lru`; `redis-expire-records=yes` | db0 184k keys (expiring ≈ keys), ~87 MiB, 0 evictions |

100k+ already met. Sizes are fine. AGH timing is not an edge cache: `unbound_prefetches_total` ≈ 76 ever — prefetch is dead today.

```text
Client → AGH (per-host RAM) → Unbound L1 (per-host slabhash) → Valkey L2 (shared yifuwuqi) → auth
```

- AGH: per-host RAM, absorb LAN QPS, re-query Unbound often.
- Unbound L1: per-host slabhash, long TTL + prefetch + serve-expired.
- Valkey L2: shared store; Redis `EX` = clamped DNS TTL + `serve-expired-ttl` (`cachedb/redis.c`: `ttl += env->cfg->serve_expired_ttl`).

## Problems

1. **AGH is not an edge cache.** `modules/services/adguardhome.nix` leaves `cache_ttl_min/max = 0`, so AGH stores Unbound's clamped 1h–7d. AGH's copy expires at the same absolute time as Unbound's (remaining TTL passed down), so its re-queries always arrive at/after Unbound expiry — serve-expired path, never the prefetch window (last 10% of TTL, `PREFETCH_TTL_CALC(ttl) = ttl - ttl/10`).
2. **Optimistic max-age is a failure window, not a refresh interval.** Verified in dnsproxy `cache.unpackItem`: expired entries are served (with `cache_optimistic_answer_ttl`) only until `expiry + cache_optimistic_max_age`, and *every* expired hit spawns a background re-resolve. So AGH already refreshes Unbound on each hit after expiry; `12h` only bounds how long a *failed* refresh may still be served. Long for an edge; cap at 1h. 30s/12h are the dnsproxy defaults (`DefaultOptimisticAnswerTTL/MaxAge`). Do not analogize it to Unbound `cache-min-ttl`.
3. **Redis EX is already aligned.** Do **not** set `redis-expire-records = no`. Unbound clamps TTLs to [1h, 7d] at wire-parse (`msgreply.c` MIN_TTL/MAX_TTL) before `cachedb_extcache_store`, then `redis_store` adds `serve-expired-ttl = 604800`: keys live **7d1h–14d**. That exactly mirrors the read-side cutoff (`good_expiry_and_qinfo`: entries older than `expiry + serve-expired-ttl` are a miss), so redis drops keys precisely when Unbound would refuse them. `no` would grow until 1 GiB LRU and collide with SearXNG db1 (`?db=1` on the same instance; `allkeys-lru` evicts across logical DBs). Live: `expiring ≈ keys`, sampled TTLs ~6.2d — EX working.

## Decisions

| Layer | Size | Fresh TTL | Stale / eviction | Role |
|-------|------|-----------|------------------|------|
| **AGH** | keep **64 MiB** | `cache_ttl_max = 300`; min 0 | optimistic answer **30s**; optimistic max age **1h** (failed-refresh cap) | small hot edge; re-hit Unbound ≥ every 5m |
| **Unbound L1** | keep **300m + 600m** | `cache-min-ttl = 3600`, `cache-max-ttl = 604800` | `serve-expired-ttl = 604800`, prefetch on | long-lived local cache; slow refresh |
| **Valkey L2** | keep **1 GiB** `allkeys-lru` | Redis `EX` = clamped TTL + 7d | keep `redis-expire-records = yes` | shared durable store; expire after stale window; LRU only if 1 GiB fills |

Invariant: **AGH max TTL (5m) ≪ Unbound min TTL (1h) ≪ Redis EX (7d1h–14d)**. Clients see ≤5m from AGH (dnsproxy `setMinMaxTTL` clamps every upstream response before caching *and* serving); Unbound/Valkey keep the long copy. Prefetch window on a min-TTL record is the last 360s; AGH's ~300s re-query cadence lands inside it for continuously-hot names. Lukewarm names miss the window and fall back to serve-expired + background refresh — same client-side latency either way.

## File changes

### 1. `modules/services/adguardhome.nix`

- Set `cache_ttl_max = 300`.
- Leave `cache_ttl_min = 0`.
- Set `cache_optimistic_max_age = "1h"` (was `12h`).
- Keep `cache_size = 67108864`, `cache_optimistic = true`, `cache_optimistic_answer_ttl = "30s"`.
- Rewrite comments: AGH ≤5m edge; Unbound ≥1h / ≤7d; Valkey EX = clamped TTL + 7d; optimistic max-age is failed-refresh cap, not refresh cadence.

### 2. `modules/services/unbound.nix`

- **Keep** `redis-expire-records = "yes"` and all mem/TTL/SWR knobs.
- Comment: Redis `EX = clamped_ttl + serve-expired-ttl` (7d1h–14d); turning EX off would desync L2 from the 7d stale window and grow until LRU.
- Fix wrong comment on `cache-max-ttl = 604800` — "unbound maximum" is false (default 86400, no hard max); it is our chosen cap.

### 3. `modules/services/valkey.nix`

- Comments only: Unbound already SET EX (clamped TTL + 7d); `maxmemory 1gb` + `allkeys-lru` is the fallback cap if EX is missing (failed `redis_init` SET-EX probe — checked once at startup, never re-probed on reconnect) and also covers SearXNG db1. No size/policy change.

## Out of scope

- Shrinking Unbound 300m/600m (live ~203 MiB used; headroom for 100k+).
- `serve-expired-ttl = 604800` vs RFC 8767's 1–3d suggestion (matches "slow long-term").
- Rewrite of stale `cache_size = 0` in `docs/src/networking/unbound-integration.md`.

## Phases

1. Edit the three module files as above (AGH values + Unbound/Valkey comments).
2. Deploy later: `nixos-rebuild switch` on `yirukou` (primary) and `yifuwuqi` (secondary).
3. Verify live (below).

## Verify after deploy (both hosts)

- AGH API / rendered store YAML: `cache_ttl_max == 300`, `cache_optimistic_max_age == 1h`.
- Dig via AGH: answer TTL ≤ 300; same name on Unbound `:5335` still 1h–7d.
- Valkey: `redis_db_keys{db="db0"}` ≥ 100k; `redis_db_keys_expiring` stays ≈ key count (EX still on). Warm-key TTL ~6–14 days (not hours; floor after a fresh store is 7d1h).
- `unbound_prefetches_total` (exporter `:9167`) starts moving once AGH re-queries inside the last 10% of Unbound TTL; `unbound_expired_total` growth should slow as prefetch takes over.
