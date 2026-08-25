# Hosted Services

The monolith server (`yifuwuqi`) runs several web applications and tools for the homelab.

These are configured in `modules/services/` and enabled via `hosts/yifuwuqi/services.nix`.

## Services

*   **Homepage (`homepage.nix`)**: A dashboard aggregating all active services. Configured declaratively with widgets pointing to AdGuard, Unbound, and other local metrics.
*   **SearXNG (`searxng.nix`)**: A privacy-respecting metasearch engine. Available at `search.fufu.land`.
*   **Valkey (`valkey.nix`)**: A Redis fork used as a centralized in-memory datastore. It primarily holds the shared DNS cache for Unbound.
*   **Cockpit (`cockpit.nix`)**: A web-based graphical interface for servers.
*   **WebDAV (`webdav.nix`)**: Simple file sharing protocol server.
*   **Firecrawl (`firecrawl.nix`)**: API service for crawling websites (usually integrated with LLMs).
*   **Forgejo & Opencode**: Covered under the CI / Binary Cache documentation.

Most services are only exposed to the `10.42.0.0/24` LAN and Tailscale, proxied via `yirukou`'s Nginx reverse proxy.
