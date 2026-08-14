# Arr Stack Setup Guide

This guide covers the manual bootstrap steps required after deploying the Arr stack (Radarr, Sonarr, Lidarr, Readarr, Prowlarr, Bazarr), qBittorrent, and Soulseek (slskd + soularr).

## Pre-Deployment Requirements

Before the first deployment, you must explicitly generate and populate the API keys in your `secrets.yaml` for the stack. You can quickly generate a block of keys for your `secrets.yaml` by running the following command in your terminal:

```bash
for app in radarr sonarr lidarr readarr prowlarr; do echo "    ${app}_api_key: $(openssl rand -hex 16)"; done
```

Place the output under the `arr:` section in your `secrets.yaml` file. These keys will be automatically injected into the applications and Recyclarr via environment variables.

## 1. Initial Authentication

- Access each service's web UI via their respective `*.fufu.land` domains through Nginx.
- Follow initial setup prompts and establish authentication as needed.

## 2. Root Folders Configuration

For Radarr, Sonarr, Lidarr, and Readarr, configure the root folders to point to the shared media directory:

- Add `/persist/media/movies` for Radarr
- Add `/persist/media/tv` for Sonarr
- Add `/persist/media/music` for Lidarr
- Add `/persist/media/books` for Readarr

## 3. qBittorrent Setup

- Navigate to qBittorrent's settings.
- Configure the default save path and incomplete download directories:
  - Complete: `/persist/media/downloads/complete`
  - Incomplete: `/persist/media/downloads/incomplete`
- **Network Interface**: Verify qBittorrent reports the Gluetun interface and the current Proton forwarded port. **Do not** manually select `wt0` (NetBird).

## 4. Download Client Integration

In each Arr app (Radarr, Sonarr, Lidarr, Readarr), add qBittorrent as a download client:

- Host: `127.0.0.1`
- Port: `8080`
- Category: `music` for Lidarr (must exist in qBittorrent)
- Provide the WebUI credentials (localhost is auth-whitelisted, so they can be empty).

## 5. Prowlarr Configuration

- In Prowlarr, add your desired indexers (see below).
- Add application integrations for Radarr, Sonarr, Lidarr, and Readarr. Use `127.0.0.1` and their respective backend ports (`7878`, `8989`, `8686`, `8787`) with the API keys from `secrets.yaml` to link them locally.
- Sync indexers to the configured applications.

**Indexers to use:**
- The Pirate Bay (Cardigann, base URL `https://thepiratebay.org/`)
- Nyaa.si (Cardigann, base URL `https://nyaa.si/`)
- LimeTorrents (Cardigann, base URL `https://www.limetorrents.lol/`)
- `Torrent-Indexer BR` (Generic Torznab, URL `http://127.0.0.1:8181/api/torznab`) — the local container scraping Brazilian public trackers, for pt-BR content
- `RuTracker.org` **should not be used**: since 2025 it requires a paid account for search/RSS and its Cloudflare challenge blocks automated login. FlareSolverr does not help. Remove it if present.

**FlareSolverr:** Cloudflare-protected indexers (e.g. EZTV) need it. Prowlarr's indexer settings show an "info_flaresolverr" note on those indexers; add a FlareSolverr indexer proxy pointing at `http://127.0.0.1:8191/` (it runs in the gluetun namespace and is published on that port). The `torrent-indexer` container uses it automatically via `FLARESOLVERR_URL` (set in `modules/services/arr/default.nix`).

**Known limitation — LimeTorrents and Lidarr:** Prowlarr refuses to sync LimeTorrents to Lidarr because its sync test (keywordless query with music categories) returns no results. Workaround: in Lidarr, add it manually via **Add Indexer > Torznab**:
- Name: `LimeTorrents (Prowlarr)`
- URL: `http://localhost:9696/<LimeTorrents-id>/` (the id is the one shown in Prowlarr's indexer list; keep `apiPath` `/api`)

Also remove any stale manual Torznab entries in Lidarr pointing at `prowlarr.fufu.land/1` (a duplicate of The Pirate Bay).

## 6. Recyclarr (TRaSH Guides Sync)

Recyclarr is fully declarative and automatically uses the API keys configured in `secrets.yaml`. It syncs the configured TRaSH profiles on a daily schedule. You can trigger it manually via `systemctl start recyclarr.service`.

## 7. Soulseek (hard-to-find music via Lidarr)

For music that torrent indexers can't provide (J-pop, indie, niche artists), the stack includes `slskd` + `soularr`:

- **slskd**: Soulseek client running in the gluetun VPN namespace. Web UI at `https://slskd.fufu.land` (login: `slskd` / the `services.slskd.web_password` secret). Downloads land in `/persist/media/downloads/soulseek`.
- **soularr**: also in the gluetun namespace; runs every 5 minutes, scans Lidarr's wanted list, searches Soulseek, downloads, and asks Lidarr to import.

Setup:

1. Create a free Soulseek account at <https://www.slsknet.org/> (nickname + password).
2. Store the credentials in `secrets.yaml` under `services.slskd.username` / `services.slskd.password`, then redeploy.
3. Add an album/artist in Lidarr (interactive search is optional — soularr picks up the wanted list automatically).
4. Verify with `journalctl -u podman-soularr`.

**Networking notes:** all traffic goes through the Proton VPN tunnel (gluetun). Inbound peer transfers to slskd are limited because the single Proton forwarded port belongs to qBittorrent; downloads are unaffected. The firewall allows containers to reach Lidarr's API for the import step (`backend-ui-guard` in `hosts/yifuwuqi/networking/firewall.nix`).

## 8. Brazilian Dubbed Content (pt-BR)

To automatically discover and download foreign movies and TV shows with Brazilian Portuguese voice acting (Dublado / Dual Áudio):

**1. Prowlarr Indexer Setup:**
The `torrent-indexer` container scrapes Brazilian public trackers (comando_torrents, bludv, filme_torrent, etc.) and is exposed on `http://127.0.0.1:8181/api/torznab`. Add it in Prowlarr as a **Generic Torznab** indexer named `Torrent-Indexer BR` (see section 5) and sync it to Radarr and Sonarr.

**2. Radarr / Sonarr Custom Formats:**
To ensure your media applications prefer files with Brazilian voice acting:
- Go to **Settings** > **Custom Formats** in Radarr/Sonarr.
- Create rules that match release titles containing regex patterns like `(?i)\b(dublado|dual(\W)?audio|pt(\W)?br)\b`.
- Go to your **Profiles** > **Quality Profiles** and assign a positive score to this Custom Format so the system automatically upgrades or prefers these releases.
*(Note: You can also define these rules declaratively via `recyclarr` in `modules/services/arr/default.nix` if you wish to fully automate TRaSH guide syncs for foreign languages).*
