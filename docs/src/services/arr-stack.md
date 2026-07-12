# Arr Stack Setup Guide

This guide covers the manual bootstrap steps required after deploying the Arr stack (Radarr, Sonarr, Lidarr, Readarr, Prowlarr, Bazarr) and qBittorrent.

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
- Provide the WebUI credentials.

## 5. Prowlarr Configuration

- In Prowlarr, add your desired indexers.
- Add application integrations for Radarr, Sonarr, Lidarr, and Readarr. Use `127.0.0.1` and their respective backend ports (`7878`, `8989`, `8686`, `8787`) to link them locally.
- Sync indexers to the configured applications.

## 6. Recyclarr (TRaSH Guides Sync)

Recyclarr is fully declarative and automatically uses the API keys configured in `secrets.yaml`. It syncs the configured TRaSH profiles on a daily schedule. You can trigger it manually via `systemctl start recyclarr.service`.

## 7. Brazilian Dubbed Content (pt-BR)

To automatically discover and download foreign movies and TV shows with Brazilian Portuguese voice acting (Dublado / Dual Áudio):

**1. Prowlarr Indexer Setup:**
A custom `torrent-indexer` container runs locally alongside the stack to scrape Brazilian public trackers.
- In Prowlarr, navigate to **Indexers** > **Add Indexer**.
- Select **Generic Torznab**.
- Name: `Torrent-Indexer BR`
- URL: `http://127.0.0.1:8181/api/torznab`
- Save and sync this indexer to Radarr and Sonarr.

**2. Radarr / Sonarr Custom Formats:**
To ensure your media applications prefer files with Brazilian voice acting:
- Go to **Settings** > **Custom Formats** in Radarr/Sonarr.
- Create rules that match release titles containing regex patterns like `(?i)\b(dublado|dual(\W)?audio|pt(\W)?br)\b`.
- Go to your **Profiles** > **Quality Profiles** and assign a positive score to this Custom Format so the system automatically upgrades or prefers these releases.
*(Note: You can also define these rules declaratively via `recyclarr` in `modules/services/arr.nix` if you wish to fully automate TRaSH guide syncs for foreign languages).*
