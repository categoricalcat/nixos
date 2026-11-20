# UID/GID Isolation and Ownership

## Status: DRAFT — inventory taken 2026-11-20 (`yifuwuqi` live; `yirukou`, `yitaishi`, `yixiaoqing` via `ai-ssh`); Phase 0 complete; Phase 1 deployed on `yifuwuqi` and `yirukou` 2026-11-20 and live-verified; Phases 3–5 landed 2026-11-20 in one change set — window run on `yifuwuqi` (renumber, rebuild, reboot) and verified live: both container-identity gauges at zero, all units healthy; Phase 2 (orphans, literals) still open

## Objective

Every host UID and GID names exactly one principal: a human, a host service, or one container. Every numeric ID used outside the account database is derived from it, and no persistent file is owned by an ID the allocator can hand out again. Regressions fail `nix flake check` for declared configuration and raise a security-monitor metric for live hosts.

### Scope

Owns: the ID allocation policy, container identities (`user`, `PUID`/`PGID`), numeric ID literals in Nix and scripts, ownership of persistent data, and the checks for all of them.

Not owned here:

- qBittorrent WebUI authentication. It stays passwordless behind the `127.0.0.1` auth whitelist (decided 2026-11-20).
- Persisting `/var/lib/nixos`, the allocator's record, on a tmpfs root. [Impermanence on yirukou](impermanence-yirukou-plan.md) already lists it.
- Ad-hoc Docker containers on `yitaishi` and `yixiaoqing`. None are declared in this repository.

## Current state

### Allocator (nixpkgs `nixos/modules/config/update-users-groups.pl`)

- Dynamic system IDs come from 400–999 counting down, normal users from 1000–29999 counting up. An ID is skipped when it is pinned in config, present in `/etc/passwd` or `/etc/group`, or recorded in `/var/lib/nixos/{uid,gid}-map`. Any other ID is free, even when files still carry it.
- A pinned `uid`/`gid` that differs from an existing account's value is never applied; activation only warns `not applying UID change`. Renumbering is a manual root step plus a filesystem sweep. A changed primary group is applied.
- NixOS asserts that pinned IDs are unique per host (`UIDs and GIDs must be unique!`).
- nixpkgs deprecates new static IDs (`ids.nix`, RFC 0052) except where IDs must be known outside the host's account database. 328–399 is unused in both `ids.nix` tables, sits below the dynamic allocator, and is unused on every reachable host.

### Container identities on `yifuwuqi`

Podman runs rootful without user namespaces (`modules/virtualisation/podman.nix`), so an in-image ID is the host ID. Live processes, mapped to containers through their cgroup and `/run/<name>/ctr-id`:

| Host uid:gid | Resolves to           | Containers                                                                                          |
| ------------ | --------------------- | --------------------------------------------------------------------------------------------------- |
| 999:999      | `avahi`:`avahi`       | `firecrawl-postgres`, `firecrawl-rabbitmq`, `pinepods-db`                                           |
| 999:1000     | `avahi`:`yi`          | `firecrawl-redis`, `pinepods-valkey`                                                                |
| 968:952      | `qbittorrent`:`media` | `qbittorrent` (Phase 0; ids from `/run/qbittorrent-ids.env`, so rendered config declares none)      |
| 1000:1000    | `yi`:`yi`             | `firecrawl-playwright` (image `User=node`; headless Chrome)                                         |
| 65534:65534  | `nobody`:`nogroup`    | `flaresolverr` (Nix-built image)                                                                    |
| 100:101      | no account            | `pinepods` nginx worker                                                                             |
| 0:0          | `root`                | `cloudflared`, `firecrawl`, `gluetun`, `pinepods`, `slskd`, `soularr`, `torrent-indexer`, `weather` |

- Files written as 999: `pinepods-db`'s `PGDATA` under `/var/lib/container-volumes/pinepods/pgdata` and the qBittorrent config volume (17 entries). The 1545 `/persist/media` entries were re-owned to `qbittorrent` (968) on 2026-11-20.
- `cloudflared.nix` builds `user` from an unpinned account, so it renders `-u ':'` (nixpkgs `oci-containers.nix`) and the container runs as root. The image default is `65532:65532`, so the line escalates it. `localtonet.nix` and `playit-agent.nix` (not imported) repeat the pattern.
- `slskd.nix` gives `soularr` `PUID = "0"` and `PGID = "952"`, a literal copy of `media`'s dynamically allocated GID.
- Phase 0, deployed in `2cdb542`: `qbittorrent` is a dynamic system account (uid 968) in group `media`, and `preStart` writes its `PUID`/`PGID` to `/run/qbittorrent-ids.env`.
- No other host runs declared containers.

### Orphaned and reusable IDs on `yifuwuqi`

| Path                                      | Owner                                | Notes                                                                                                                                                                                                                 |
| ----------------------------------------- | ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/srv/webdav` (0775; nginx test files)    | `root`:`nginx` (re-owned 2026-11-20) | The predicted collision materialized: the deployed `qbittorrent` account took 968 and owned the orphaned directory; `chown root /srv/webdav` done and verified (`0:60 root:nginx 775`). `webdav.nix` is not imported. |
| `/srv/nfs/share` (0775; `latest.tar.zst`) | uid 1007 (no account), gid 967       | gid 967 is now `searx`, so the `searx` group can write here. NFS was removed 2026-03-21 (`a8ba048`).                                                                                                                  |
| `/srv/nextcloud` (0750)                   | 975:972, retired `nextcloud`         | Recorded in the maps, so not reusable. The module is not imported.                                                                                                                                                    |
| `/persist/media/podcasts` and one child   | uid 949, retired `audiobookshelf`    | Recorded, not reusable. `pinepods` writes here as root.                                                                                                                                                               |

### Literals and shared groups

- `users/users.nix` pins `yi` 1000, `workd` 1001 and `none` 1002 (UID equals GID); live values match on all four reachable hosts. The numbers are repeated as literals in `modules/desktop/gnome/default.nix` (geoclue `users = [ "1000" ]`, twice), `hosts/yitaishi/hardware.nix` (`uid=1000`, `gid=1000`) and `users/scripts/nix-fix-uids.sh` (its account table and `/srv/shares/share`).
- `nix-builder` and `ai` use `nogroup` as their primary group, the group `flaresolverr` runs under. `/var/lib/nix-builder` is mode 0700.

### Already compliant

- No duplicate UID or GID in live `passwd`/`group` on `yifuwuqi`, `yirukou`, `yitaishi` or `yixiaoqing`. `yichuang` is outside the `ai-ssh` registry and was not inspected.
- `DynamicUser` services, nixpkgs static IDs below 400, and the Samba client (`uid=yi,gid=yi`, resolved by name). Nothing shares numeric IDs across hosts since NFS was removed.

## Decisions

1. **One principal per ID.** Group sharing is deliberate and named (`media`). No container runs with an ID that names an unrelated account, or as `nobody`/`nogroup`.
1. **Each container runs as its own declared account.** Plain images get `user = "<uid>:<gid>"`; images with `PUID`/`PGID` support get those. Both read `config.users.users.<name>.uid` and `config.users.groups.<name>.gid`. Host root requires a reason recorded on the container (`gluetun`: `NET_ADMIN` and `/dev/net/tun`). Ownership, `ps` and the audit then resolve to names without subordinate-ID setup. Per-container user namespaces are the stronger alternative (Open questions).
1. **Pin only IDs that leave the account database, in 330–399.** Podman renders `user` into the unit's start script at evaluation time, so container accounts need a number then; host-only accounts stay dynamic. The block cannot collide with an allocated ID, and the per-host assertion catches clashes between pins. A container account uses one number for its UID and its own group's GID, declared next to the account. Humans keep 1000–1002.
1. **No ID literals outside the declaration.** Nix consumers read the account database; scripts get IDs substituted from Nix or resolve names at runtime.
1. **Orphans first, sweep after.** Files owned by unrecorded or reused IDs are re-owned or deleted before accounts are created or renumbered. Every renumbering ends with a sweep of the old ID, because the allocator treats an ID it no longer records as free.
1. **Two checks.** A contract in `nix/checks.nix` validates declared identities; the security monitor's fast audit validates live hosts.

### ID assignments

| ID  | Account or group                      | Used by                                |
| --- | ------------------------------------- | -------------------------------------- |
| 330 | group `media`                         | arr services, `qbittorrent`, `soularr` |
| 331 | `qbittorrent` (primary group `media`) | `qbittorrent`                          |
| 332 | `cloudflared`                         | `cloudflared`                          |
| 333 | `flaresolverr`                        | `flaresolverr`                         |
| 334 | `firecrawl-postgres`                  | `firecrawl-postgres`                   |
| 335 | `firecrawl-rabbitmq`                  | `firecrawl-rabbitmq`                   |
| 336 | `firecrawl-redis`                     | `firecrawl-redis`                      |
| 337 | `firecrawl-playwright`                | `firecrawl-playwright`                 |
| 338 | `pinepods-db`                         | `pinepods-db`                          |
| 339 | `pinepods-valkey`                     | `pinepods-valkey`                      |
| 340 | `soularr` (primary group `media`)     | `soularr`                              |
| 341 | `slskd` (primary group `media`)       | `slskd`                                |
| 342 | `torrent-indexer`                     | `torrent-indexer`                      |
| 343 | `firecrawl`                           | `firecrawl`                            |
| 344 | `pinepods` (primary group `media`)    | `pinepods`                             |
| 345 | `weather`                             | `weather`                              |

All assigned through 345; new container accounts continue from 346.

## Phases

### Phase 0 — Finish the qBittorrent stopgap

Deployed in `2cdb542` and verified live 2026-11-20; all steps done:

1. Done, verified 2026-11-20: `chown root /srv/webdav` (`stat` → `0:60 root:nginx 775`), so the account does not keep the orphaned directory.
1. Done: media re-own — `find /persist/media -xdev -uid 999 -exec chown -h qbittorrent {} +` moved 1545 entries; `find /persist/media -xdev -uid 999` now prints nothing. The unit's `preStart` re-owns the config volume.
1. Done, verified: `id -u qbittorrent` → 968; `ps -o uid,gid,comm -C qbittorrent-nox` → `968 952 qbittorrent-nox`.

### Phase 1 — Live audit

Implemented 2026-11-20, deployed on `yifuwuqi` the same day and live-verified (`yirukou` deploy pending). The first three gauges extend the fast audit `modules/services/monitoring/security-monitor/scripts/system-audit.sh` (root, every 15 minutes); `node_security_unowned_files` lands in the daily `cve-scan.sh` instead — the root-filesystem sweep measured ~7 minutes wall there (I/O-bound, ~50 s CPU), too heavy for a 15-minute cadence:

- `node_security_duplicate_ids{kind}`: IDs that appear twice in `/etc/passwd` or `/etc/group`.
- `node_security_container_shared_id{container,kind,name}`: a non-root container process whose host UID or GID resolves to an account or group other than that container's declared identity (its `user`, or `PUID`/`PGID` in `environment`). Nix renders the declared identities from `virtualisation.oci-containers.containers`; processes map to containers via `/machine.slice/libpod-<ctr-id>.scope` and `/run/<name>/ctr-id`.
- `node_security_container_root{container}`: a container process running as host root without a recorded reason.
- `node_security_unowned_files`: entries without an account or group, from `find / -xdev \( -path /nix -o -path /var/lib/containers \) -prune -o \( -nouser -o -nogroup \) -print`. All of `yifuwuqi`'s data, including `/persist` and `/srv`, lives on the root filesystem; image layers carry in-image IDs.

The sweep was parallelized the same day (pre-redeploy in the working tree): depth-2 subtrees are walked by concurrent `find` workers, with a shallow serial pass covering depth-1/2 entries and workers starting at `-mindepth 1` — set-identical to the serial walk, verified by total-visited comparison. Workers run line-buffered (`stdbuf -oL`): `find`'s block-buffered writes exceed `PIPE_BUF` and tear when racing into the shared output pipe, nondeterministically undercounting. Rootless-podman storage stays in the sweep by decision, so its subordinate-ID files count as unowned from the host and `SecurityUnownedFiles` cannot read zero while rootless containers hold volumes.

Panels in `modules/services/monitoring/dashboards/security.nix`; alert rules (non-zero for one hour) in `modules/services/monitoring/rules/workloads.yml`, group `security-identity` — the `SecurityContainerRoot` rule landed 2026-11-20 with the Phase 4 reasons (`gluetun`, `qbittorrent`), so the gauge now alerts and reads zero once the window deploys.

Measured first run on `yifuwuqi` (2026-11-20, user-run, so a lower bound): duplicate IDs 0/0 — verified clean; shared-ID rows for the 999, 968, 1000 and 65534 rows (`qbittorrent` is the 968 row and stays listed until Phase 4, because its IDs come from a runtime file); ten root containers, two more than the manual inventory — `qbittorrent`'s image s6 init and `pinepods-valkey`'s `tini` entrypoint run as root; 2932 unowned files — `/var/lib/omada` (2586) and `/opt/netdata` (203) retired-service state, rootless-podman overlay dirs under `/home/yi/.local/share/containers`, and the orphan table. Phase 2's sweep is bigger than the orphan table suggested.

Deployed baseline (first live timer run 13:05, 2026-11-20): duplicate IDs 0/0, the same 16 shared-ID series and ten root containers as the user-run, all 28 series scraped by Prometheus with the `security-identity` rules loaded. `SecurityContainerSharedId` sits at pending and fires by design until Phase 3 gives the 999/1000/65534-row containers their own accounts and Phase 4 pins `qbittorrent`. `yirukou`, manually fired at 13:25 the same day: duplicate IDs 0/0 and no container series (it runs no containers).

### Phase 2 — Orphans, literals and shared groups

1. Apply the answers to Open questions 2–4: re-own or delete each orphan path as root, then rerun the audit.
1. Literal human IDs: geoclue `users` and the `yitaishi` NTFS options read `config.users.users.yi.uid` and `config.users.groups.yi.gid`. `nix-fix-uids.sh` takes its table from `users/users.nix` through `pkgs.writeShellApplication`, or is deleted.
1. Give `nix-builder` and `ai` their own dynamic groups (activation applies primary-group changes), then `chgrp -R nix-builder /var/lib/nix-builder` as root on each host.

### Phase 3 — Dedicated accounts for non-root containers

Declare accounts 333–339 from the ID table as `isSystemUser` with a same-numbered group, and set each container's `user` from them. The accounts are new, so activation creates them at the pinned numbers. Configuration implemented 2026-11-20; per-image findings resolved in the same change set:

| Container                            | Resolution                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `pinepods-db`                        | `user = "338:338"`; tmpfiles own `pgdata 0700` to the account. The window chowns the existing volume contents (999-owned) before start. The official postgres image documents arbitrary `--user` support when `PGDATA` is owned by that UID.                                                                                                                                                                                   |
| `firecrawl-postgres`                 | `user = "334:334"`; new account-owned volume at `/var/lib/container-volumes/firecrawl/pgdata:/var/lib/pgdata` with `PGDATA=/var/lib/pgdata/data`, outside the image VOLUME (docker-library/postgres#1363 overlay bind-mount failure) — required because initdb as the account needs an empty writable dir, and it also fixes data loss on every podman auto-update recreation. Fresh DB on first boot; the app re-initializes. |
| `firecrawl-redis`, `pinepods-valkey` | `user = "336:336"` / `"339:339"`; no host volume, image `/data` stays in-image-owned, so snapshots are off (`cmd ... --save ""` — both are caches).                                                                                                                                                                                                                                                                            |
| `firecrawl-rabbitmq`                 | `user = "335:335"`; new account-owned volume at `/var/lib/container-volumes/firecrawl/rabbitmq:/var/lib/rabbitmq` (HOME and mnesia must be writable by the account; fresh broker state on first boot).                                                                                                                                                                                                                         |
| `firecrawl-playwright`               | `user = "337:337"`; `HOME=/tmp` — the image HOME is owned by the in-image node user.                                                                                                                                                                                                                                                                                                                                           |
| `flaresolverr`                       | `user = "333:333"` overrides the image-baked `nobody:nogroup`. Nothing to migrate (`HOME=/tmp`, no state).                                                                                                                                                                                                                                                                                                                     |

Verify at the window: the shared-ID gauge only lists `qbittorrent` (until its renumber applies); the firecrawl readiness gates (`ExecStartPost` probes) and the Pinepods UI work.

### Phase 4 — Renumber existing accounts and land the contract

Configuration implemented 2026-11-20:

- `users.groups.media.gid = 330` and `users.users.qbittorrent.uid = 331`. qBittorrent's `PUID`/`PGID` moved into `environment`, read from the account database; `/run/qbittorrent-ids.env` and its `preStart` lines are gone.
- `cloudflared` pinned to 332 (uid and group); its `user` now renders `332:332`.
- **Correction:** `soularr`'s `PUID`/`PGID` were dead config — upstream `run.sh` is a plain bash loop that never reads them (no s6/su), so the container always ran as root. Identity now comes from podman: `user = "340:330"` with the account in group `media`. Its log file moved to `/data/soularr.log` (absolute), since the image CWD `/app` is not writable by the account.
- **Invariant found at the window:** sops templates bind-mounted into unprivileged containers must be owned by their account (`sops.templates."slskd.yml".owner = "slskd"`, same for `soularr.ini`; sops default `root:root 0400` crashed slskd's config load and made soularr read an empty config). `environmentFiles` and `preStart`-copied templates stay root-owned — rootful podman and preStart run as root.
- A `rootReason` option on the container submodule in `modules/virtualisation/podman.nix`, set on `gluetun` (NET_ADMIN and `/dev/net/tun`) and `qbittorrent` (linuxserver s6 init drops to PUID/PGID) only — no interim reasons, because Phase 5 landed in the same change set. The fast audit skips root processes for containers with a recorded reason, and the `SecurityContainerRoot` alert (root gauge non-zero for one hour) is on.
- Contract `container-identity` in `nix/checks.nix`, per host: each container has numeric `user` fields, numeric `PUID`/`PGID`, or a root reason; each declared uid and gid is pinned in 330–399 on an account or group; no two containers share a UID.

NixOS does not renumber existing accounts, so the window on `yifuwuqi` runs as root. Live ids (verified 2026-11-20): `cloudflared` 984:979, `qbittorrent` 968:952, `media` 952.

```bash
systemctl stop podman-qbittorrent podman-soularr podman-slskd podman-torrent-indexer podman-pinepods \
  podman-pinepods-db podman-pinepods-valkey podman-firecrawl podman-cloudflared podman-flaresolverr \
  podman-weather radarr sonarr lidarr readarr bazarr jellyfin
groupmod -g 330 media
usermod -u 331 qbittorrent
groupmod -g 332 cloudflared
usermod -u 332 cloudflared
find / -xdev \( -path /nix -o -path /var/lib/containers \) -prune -o -gid 952 -exec chgrp -h media {} +
find / -xdev \( -path /nix -o -path /var/lib/containers \) -prune -o -uid 968 -exec chown -h qbittorrent {} +
find / -xdev \( -path /nix -o -path /var/lib/containers \) -prune -o \( -uid 984 -o -gid 979 \) -print
# re-own anything the last find prints (the cloudflared container has no volumes; expect nothing)
chown -R pinepods-db:pinepods-db /var/lib/container-volumes/pinepods/pgdata
chown -R slskd:media /var/lib/container-volumes/slskd
chown -R soularr:media /var/lib/container-volumes/soularr
```

The arr services stop because running processes keep the old `media` gid and would mint 952-owned files. `gluetun` keeps running (nothing shares its id); its consumers restart with it. Then deploy (`nixos-rebuild switch` — activation creates accounts 333–345 and the tmpfiles volume dirs) and `systemctl start` the stopped units; units the switch already started are unaffected.

Verify: activation prints no `not applying` warning; `id qbittorrent` shows 331 and group 330; the shared-ID, root and duplicate-ID gauges read zero (root counts only unreasoned containers: `gluetun` and `qbittorrent` are suppressed); `nix flake check --no-build` passes with the contract.

### Phase 5 — De-root the remaining containers

Configuration implemented 2026-11-20 in the same change set as Phases 3–4 (image checks done up front; the window verifies all at once):

- `slskd` (341, group `media`): upstream documents Docker's `--user` as the supported host-identity mechanism (preferred over its root-then-chown `PUID`/`PGID` fallback) — `user = "341:330"`.
- `torrent-indexer` (342): the published image runs `/app/torrent-indexer` (the repo Dockerfile's `/root` placement is stale), so `user = "342:342"` works; stateless.
- `firecrawl` (343): stdout logging, `/tmp` scratch, no `/app` writes found in the image env — `user = "343:343"`; verify via the unit's readiness gate plus a test scrape at the window.
- `pinepods` (344, group `media`): `PUID`/`PGID` are honored — the startup script remaps its in-image user, `chown`s its volumes and ends with `exec su-exec PUID:PGID horust`, so every process runs as 344:330 with no lingering root. It self-heals `/persist/media/podcasts` (one-time recursive chown to 344:330, marked by `.perms-migrated`).
- `weather` (345): stateless Node server — `user = "345:345"`.
- `gluetun` keeps root (recorded reason); `qbittorrent`'s s6 init keeps root (recorded reason) while the app runs as 331:330.

Then retire this plan once Phase 2's items also close.

## Rollout order

- [x] **0.1** Re-own `/srv/webdav` (User; done and verified 2026-11-20, `root:nginx 775`).
- [x] **0.2** Verify the stopgap (AI; done 2026-11-20).
- [x] **1.1** Implement the audit gauges, panel and alerts; run fmt, lint and eval (AI; done 2026-11-20, example-run verified).
- [x] **1.2** Deploy every host (User); record the baseline from the textfile (AI; done 2026-11-20, `yifuwuqi` and `yirukou`).
- [ ] **2.1** Answer Open questions 2–4 (User).
- [ ] **2.2** Orphan cleanup (User); literal and group changes (AI); deploy (User).
- [x] **3.1** Dedicated accounts and per-image checks (AI; config done 2026-11-20); deploy `yifuwuqi` (User; done 2026-11-20); verify (AI; done — all units healthy, gauges zero).
- [x] **4.1** Prepare the pinned configuration and the contract (AI; done 2026-11-20, with the soularr correction).
- [x] **4.2** Maintenance window: stop, renumber, sweep, deploy, start (User; run 2026-11-20, followed by a reboot).
- [x] **4.3** Verify: no activation warnings, audit at zero, contract passes (AI; done 2026-11-20 — root and shared-ID gauges emit no series, `nix flake check --no-build` passes, live IDs 331/330/332).
- [x] **5.1** De-root containers (AI, User; done 2026-11-20 — all five verified live; reasons recorded on `gluetun` and `qbittorrent` only).
- [ ] **5.2** Retire this plan in the completing change set (AI; blocked on Phase 2 items: open questions 2–4, orphan cleanup, literal and group changes).

Phase 1 lands first so every later step is measured. `/srv/webdav` must be re-owned before 4.2: renumbering `qbittorrent` releases 968 to the allocator again. Phases 3 and 4 touch the same host and can share one window; the contract lands with Phase 4 because it only passes then.

## Open questions

1. **User namespaces instead of host accounts?** `--userns=auto` would give each container a private ID range and also de-root the root containers. It needs subordinate ranges for the `containers` user, idmapped mounts for `media`-shared volumes, and proof that `--network=container:gluetun` works across user namespaces (otherwise that group becomes a pod). Default: no; reconsider in Phase 5 for whatever still needs root.
1. **Orphan data:** delete or keep `/srv/webdav` (nginx test files), `/srv/nfs` (one `latest.tar.zst`) and `/srv/nextcloud`? Re-own `/persist/media/podcasts` to `root:media`?
1. **`users/scripts/nix-fix-uids.sh`:** is it still needed? Its table duplicates `users/users.nix`.
1. **`localtonet.nix` and `playit-agent.nix`:** not imported, and both carry the `user = ":"` bug. Fix them with pinned accounts, or delete them?
1. **`yichuang`:** no `ai-ssh` access. Inventory it by hand, or wait until it joins the registry?
