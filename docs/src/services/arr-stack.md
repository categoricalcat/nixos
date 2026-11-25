# Arr Stack Setup Guide

This guide covers the manual bootstrap steps required after deploying the Arr stack (Radarr, Sonarr, Lidarr, Readarr, Prowlarr, Bazarr), qBittorrent, and Soulseek (slskd + soularr).

## Pre-Deployment Requirements

Before the first deployment, you must explicitly generate and populate the API keys in your `secrets.yaml` for the stack. You can quickly generate a block of keys for your `secrets.yaml` by running the following command in your terminal:

```bash
for app in radarr sonarr lidarr readarr prowlarr; do echo "    ${app}_api_key: $(openssl rand -hex 16)"; done
```

Place the output under the `arr:` section in your `secrets.yaml` file. The applications receive these keys as `*__AUTH__APIKEY` environment variables; Recyclarr reads them through systemd credentials (`LoadCredential`), not environment variables.

## Port remap (mutable DBs)

Nix only moves listen/proxy ports. After switching host ports to the `24xxx` range, update stored URLs in each UI (they are not rewritten):

- qBittorrent download clients in Radarr/Sonarr/Lidarr/Readarr: `127.0.0.1:24080` (not `8080`).
- Prowlarr FlareSolverr proxy: `http://127.0.0.1:24191/` (host). torrent-indexer still uses `8191` inside gluetun.
- Prowlarr Generic Torznab torrent-indexer: `http://127.0.0.1:24181/api/torznab`.
- Prowlarr application integrations: `127.0.0.1` with Radarr `24878`, Sonarr `24989`, Lidarr `24686`, Readarr `24787`. Lidarr manual Torznab: `http://localhost:24696/<id>/`.
- Seerr / Jellyseerr: Jellyfin server URL if it still has `:8096` (listen is now `24096`).
- Jellyfin: the preStart only rewrites an existing `network.xml`, so a genuinely first deploy listens on the default port until one restart.
- Unbound on `yirukou`: confirm it can reach its own Valkey at `/run/redis/redis.sock` (host-local; it no longer connects to `yifuwuqi`).

## 1. Authentication

- Access each service's web UI via their respective `*.aset.love` domains through Nginx. The Authelia gate on `yirukou` is the only login: Radarr, Sonarr, Lidarr, Readarr and Prowlarr run with `AuthenticationMethod=External` (`*__AUTH__METHOD`), Bazarr with no auth type, and slskd with web authentication disabled.
- API clients (Prowlarr, Recyclarr, soularr, Seerr) keep using the API keys above over loopback, never the gated hostnames.
- Seerr (`jellyseerr.aset.love`) still has its own login, which it cannot delegate; it sits behind the gate as well. Store its password in Vaultwarden.

## 2. Root Folders Configuration

For Radarr, Sonarr, Lidarr, and Readarr, configure the root folders to point to the shared media directory:

- Add `/persist/media/movies` for Radarr
- Add `/persist/media/tv` for Sonarr
- Add `/persist/media/music` for Lidarr
- Add `/persist/media/books` for Readarr

## 3. qBittorrent Setup

The unit enforces the save paths and the network interface on every start, so the only manual check left is the forwarded port:

- **Network Interface**: Verify qBittorrent reports the Gluetun interface and the current Proton forwarded port.
- Paths (`/persist/media/downloads/complete`, `.../incomplete`) are written by the preStart, overriding UI edits of those two settings. Changing them means editing `modules/services/qbittorrent-vpn.nix`.

## 4. Download Client Integration

In each Arr app (Radarr, Sonarr, Lidarr, Readarr), add qBittorrent as a download client:

- Host: `127.0.0.1`
- Port: `24080`
- Category: `music` for Lidarr — the arr app creates the category in qBittorrent on save/test, so nothing has to exist beforehand.
- Provide the WebUI credentials (localhost is auth-allowlisted, so they can be empty).

## 5. Prowlarr Configuration

- In Prowlarr, add your desired indexers (see below).
- Add application integrations for Radarr, Sonarr, Lidarr, and Readarr. Use `127.0.0.1` and their respective backend ports (`24878`, `24989`, `24686`, `24787`) with the API keys from `secrets.yaml` to link them locally.
- Sync indexers to the configured applications.

**Indexers to use:**

- The Pirate Bay (Cardigann, base URL `https://thepiratebay.org/`)
- Nyaa.si (Cardigann, base URL `https://nyaa.si/`)
- LimeTorrents (Cardigann, base URL `https://www.limetorrents.lol/`)
- `Torrent-Indexer BR` (Generic Torznab, URL `http://127.0.0.1:24181/api/torznab`) — the local container scraping Brazilian public trackers, for pt-BR content
- `RuTracker.org` **should not be used**: since 2025 it requires a paid account for search/RSS and its Cloudflare challenge blocks automated login. FlareSolverr does not help. Remove it if present.

**FlareSolverr:** Cloudflare-protected indexers (e.g. EZTV) need it. Prowlarr's indexer settings show an "info_flaresolverr" note on those indexers; add a FlareSolverr indexer proxy pointing at `http://127.0.0.1:24191/` (host publish of the gluetun mapping `24191:8191`). `torrent-indexer` shares the gluetun namespace, so it reaches FlareSolverr at `http://127.0.0.1:8191` via `FLARESOLVERR_URL` (set in `modules/services/arr/default.nix`).

**Known limitation — LimeTorrents and Lidarr:** Prowlarr refuses to sync LimeTorrents to Lidarr because its sync test (keywordless query with music categories) returns no results. Workaround: in Lidarr, add it manually via **Add Indexer > Torznab**:

- Name: `LimeTorrents (Prowlarr)`
- URL: `http://localhost:24696/<LimeTorrents-id>/` (the id is the one shown in Prowlarr's indexer list; keep `apiPath` `/api`)

Also remove any stale manual Torznab entries in Lidarr pointing at `prowlarr.aset.love/1` (a duplicate of The Pirate Bay).

## 6. Recyclarr (TRaSH Guides Sync)

Recyclarr is declarative: keys arrive through systemd credentials, and the nixpkgs module renders `config.yml` while the unit installs `settings.yml` plus the pt-BR custom-format JSON. It syncs on the maintenance slot `*-*-* 04:15:00` (with up to 5m jitter), so the timer fires around 04:17. Trigger it manually with `systemctl start recyclarr.service`.

Scope is quality definitions (movie/series), the `All-in-One` quality profiles, and the pt-BR custom format from §8. Lidarr and Readarr are unsupported: the recyclarr config schema only admits `sonarr` and `radarr`.

## 7. Soulseek (hard-to-find music via Lidarr)

For music that torrent indexers can't provide (J-pop, indie, niche artists), the stack includes `slskd` + `soularr`:

- **slskd**: Soulseek client running in the gluetun VPN namespace. Web UI at `https://slskd.aset.love` (no login of its own; behind the Authelia gate). Downloads land in `/persist/media/downloads/soulseek`.
- **soularr**: also in the gluetun namespace; runs every 5 minutes, scans Lidarr's wanted list, searches Soulseek, downloads, and asks Lidarr to import.

Setup:

1. Create a free Soulseek account at <https://www.slsknet.org/> (nickname + password).
1. Store the credentials in `secrets.yaml` under `services.slskd.username` / `services.slskd.password`, then redeploy.
1. Add an album/artist in Lidarr (interactive search is optional — soularr picks up the wanted list automatically).
1. Verify with `journalctl -u podman-soularr`.

**Networking notes:** all traffic goes through the Proton VPN tunnel (gluetun). Inbound peer transfers to slskd are limited because the single Proton forwarded port belongs to qBittorrent; downloads are unaffected. soularr reaches Lidarr because gluetun's `FIREWALL_OUTBOUND_SUBNETS` routes the host LAN address out of the tunnel (firewall and routing together). The host's `extraInputRules` stays the port-level gate: `FIREWALL_OUTBOUND_SUBNETS` widens the namespace to the whole destination, so never widen the host rule to match. gluetun owns a fixed network (`containers.gluetun.network`, `172.19.0.0/24`, host `.2`), and the Lidarr rule admits that one address — Lidarr carries no login of its own now that the Authelia gate fronts the UI, so a subnet-wide rule would give every container unauthenticated control. The arr web UIs bind loopback behind the `yifuwuqi` local ingress; Lidarr is the exception, bound to the LAN address so soularr (in the gluetun namespace) can reach it — the ingress fronts it there too.

**HTTP proxy:** gluetun also runs an unauthenticated HTTP proxy, published loopback-only at `127.0.0.1:8889` (port 8888 inside the namespace). Prowlarr's indexer proxy or an arr app's own proxy settings may point at it; the LAN and tailnet addresses no longer answer, so any stored consumer must use the loopback address.

## 8. Brazilian Dubbed Content (pt-BR)

To automatically discover and download foreign movies and TV shows with Brazilian Portuguese voice acting (Dublado / Dual Áudio):

**1. Prowlarr Indexer Setup:**
The `torrent-indexer` container scrapes Brazilian public trackers (comando_torrents, bludv, filme_torrent, etc.) and is exposed on `http://127.0.0.1:24181/api/torznab`. Add it in Prowlarr as a **Generic Torznab** indexer named `Torrent-Indexer BR` (see section 5) and sync it to Radarr and Sonarr.

**2. Radarr / Sonarr Custom Formats:**
The pt-BR format is declarative: `modules/services/arr/default.nix` generates a local recyclarr `custom-formats` resource provider (`settings.yml` + one JSON) and both instances assign it to `All-in-One`. The score (50) lives once, as `trash_scores.default` in that JSON; recyclarr applies it to every assigning profile.

To change the title matching, edit the `ReleaseTitleSpecification` regex there — not in the UI, which the next sync overwrites. The shipped pattern is `(?i)(?:^|[^a-z0-9])(dublado|dual[\W_]?(?:[aá]udio)|pt[\W_]?br)(?:$|[^a-z0-9])`. It replaces an earlier `\b`-anchored form that missed `Dual-Áudio`, `DUALÁUDIO` and `_DUBLADO_` (accented `Áudio`; `_` is a word character, so `\b` never fires).

Assigning a score alone does not force a preference; raise the profile's `min_format_score` if you want pt-BR releases to be required rather than merely preferred.

## 9. Podcasts (Pinepods)

Pinepods (`modules/services/pinepods.nix`) is a podcast catcher. It downloads other people's shows and does not publish any. It runs with its own Postgres and Valkey sidecars on an internal container network; state lives under `/var/lib/container-volumes/pinepods`, with downloaded podcasts stored in `/persist/media/podcasts`:

1. Open `https://pinepods.aset.love` and create the first admin account when prompted. Pinepods stays outside the Authelia gate so podcast and mobile clients can reach its API; store the account in Vaultwarden.
1. Import subscriptions via OPML (Settings → Import/Export) or add podcasts by search/RSS.
1. Configure automatic downloads or download specific episodes directly from the web interface.
