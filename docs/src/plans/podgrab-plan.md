# Podgrab Migration Plan (Replacing Audiobookshelf)

## Status: PLANNED

## Objective

Replace the Audiobookshelf podcast catcher on `yifuwuqi` with Podgrab (`akhilrex/podgrab`), preserving the existing podcast storage path (`/persist/media/podcasts`), domain (`cast.fufu.land`), and network port allocation (`24085`).

## Current State

- Audiobookshelf is configured as a native NixOS service in `modules/services/audiobookshelf.nix` and imported in `hosts/yifuwuqi/services.nix`.
- Network allocation in `modules/addresses.nix` registers `audiobookshelf = { domain = "cast.fufu.land"; port = 24085; };`.
- Nginx reverse proxy on `yirukou` (`modules/services/nginx-proxy.nix`) routes `cast.fufu.land` to `http://10.42.0.2:24085`.
- Homepage dashboard (`modules/services/homepage.nix`) displays "Audiobookshelf" under the Media group.
- Podcast files live under `/persist/media/podcasts` (owned by `root:media` with setgid `2775`).
- Audiobookshelf internal database/cache lives at `/var/lib/audiobookshelf`.

## Decisions

1. **Deployment Architecture**:
   - Podgrab is packaged and distributed upstream as an OCI container (`akhilrex/podgrab:latest`).
   - Run Podgrab via `virtualisation.oci-containers.containers.podgrab`, adhering to the standard container patterns used across the repo (e.g. `weather.nix`, `firecrawl.nix`, `torrent-indexer`).
1. **Ports and Networking**:
   - Container port: Podgrab listens on internal port `8080`.
   - Host publishing: Map host port `24085` to container `8080` (`"${toString addrs.services.podgrab.port}:8080"`).
   - Domain: Keep `cast.fufu.land` as the domain for the podcast downloader.
1. **Storage & Permissions**:
   - Configuration / SQLite DB volume: `/var/lib/container-volumes/podgrab:/config`.
   - Media volume: `/persist/media/podcasts:/assets`.
   - Extra options: `--umask=0002` so that downloaded files in `/persist/media/podcasts` remain group-writable by group `media` (GID 952).
   - `systemd.tmpfiles.rules`: ensure `/var/lib/container-volumes/podgrab` (0755 root root) and `/persist/media/podcasts` (2775 root media) exist.
1. **Environment Settings**:
   - `CHECK_FREQUENCY = "60"` (minutes between checks for new episodes).
1. **Dashboard & Nginx Integration**:
   - In `modules/addresses.nix`, rename `services.audiobookshelf` to `services.podgrab`.
   - In `modules/services/nginx-proxy.nix`, proxy `podgrab.domain` to `podgrab.port`.
   - In `modules/services/homepage.nix`, replace "Audiobookshelf" card with "Podgrab", icon `podgrab.png`, ping `serviceDomains.podgrab`.
1. **Documentation**:
   - Update `docs/src/services/arr-stack.md`, `docs/src/services/hosted-services.md`, `docs/src/hosts/yifuwuqi.md`, and `docs/src/hosts/yirukou.md`.

## Phases

### Phase 1: Address Map & Service Module

- In `modules/addresses.nix`, replace `audiobookshelf` with `podgrab`.
- Remove `modules/services/audiobookshelf.nix`.
- Create `modules/services/podgrab.nix` configuring `virtualisation.oci-containers.containers.podgrab` and tmpfiles rules.
- Update `hosts/yifuwuqi/services.nix` to import `../../modules/services/podgrab.nix`.

### Phase 2: Reverse Proxy & Homepage Dashboard

- In `modules/services/nginx-proxy.nix`, update reverse proxy definition to reference `yifuwuqiServices.podgrab`.
- In `modules/services/homepage.nix`, update service domain and item card to `Podgrab` with icon `podgrab.png`.

### Phase 3: Documentation

- Update `docs/src/services/arr-stack.md` (section 9).
- Update `docs/src/services/hosted-services.md`.
- Update `docs/src/hosts/yifuwuqi.md`.
- Update `docs/src/hosts/yirukou.md`.

### Phase 4: Non-destructive Verification

- Run `statix check` and `deadnix` on modified files.
- Run `nix eval` on `yifuwuqi` and `yirukou` configurations to verify clean evaluation without errors.
- Run `git diff` to ensure clean, precise modifications.

## Rollout Order

1. Deploy `yifuwuqi` (`nixos-rebuild switch --flake .#yifuwuqi`).
   - Stops and removes `audiobookshelf.service`.
   - Pulls `akhilrex/podgrab:latest` and starts `podman-podgrab.service`.
   - Mounts `/persist/media/podcasts` to `/assets` and `/var/lib/container-volumes/podgrab` to `/config`.
1. Deploy `yirukou` (`nixos-rebuild switch --flake .#yirukou`).
   - Reloads nginx reverse proxy to route `cast.fufu.land` to Podgrab.
1. Verify:
   - Check container status: `podman ps --filter name=podgrab`.
   - Check HTTP response: `curl -kL https://cast.fufu.land`.
1. (Optional cleanup):
   - Remove legacy state directory `/var/lib/audiobookshelf` if no longer needed.

## Open Questions

None.
