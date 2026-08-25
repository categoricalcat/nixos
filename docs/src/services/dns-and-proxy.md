# DNS and Reverse Proxy

The network uses a dual-DNS pipeline and `nginx` reverse proxying to serve both the internal LAN and exposed services.

## DNS Pipeline

The core DNS stack is configured through `modules/services/adguardhome.nix` and `modules/services/unbound.nix`. It runs on both `yirukou` (the router) and `yifuwuqi` (the monolith server).

1.  **AdGuard Home (The Edge)**
    - Binds to `0.0.0.0` to handle client queries.
    - Uses an aggressive memory cache (`cache_enabled = true`, `cache_optimistic = true`) with a 64 MiB limit to answer queries instantly.
    - Responsible for blocking trackers and ads using the Hagezi blocklists.
    - Resolves local `.fufu.land` domains using custom rewrites.
    - Forwards all non-local queries upstream to the local Unbound instance.

2.  **Unbound (The Recursive Resolver)**
    - Binds to `127.0.0.1:5335`.
    - Handles actual iterative resolution (DNSSEC validation, recursion).
    - Uses a large shared second-level cache (L2) backed by a Valkey instance on `yifuwuqi`. This means both `yirukou` and `yifuwuqi` share the same global DNS cache over the network.
    - Caches records aggressively (up to 7 days) and serves stale records to clients during background revalidation (SWR).

## Reverse Proxy (Ingress)

`yirukou` acts as the main ingress point using `modules/services/nginx-proxy.nix`.

-   It terminates TLS using a wildcard `*.fufu.land` ACME certificate.
-   Proxies public and internal web interfaces (e.g., `adguard.fufu.land`, `search.fufu.land`, `agent.fufu.land`).
-   Most requests are forwarded over the LAN (`10.42.0.2`) to the respective services running on `yifuwuqi`.

Additionally, `cloudflared` (`modules/services/cloudflared.nix`) is enabled on `yifuwuqi` for specific tunnel-based ingress without opening firewall ports directly to the internet.
