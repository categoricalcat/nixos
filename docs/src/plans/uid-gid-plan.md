# UID/GID Isolation and Ownership

## Status: DRAFT — inventory taken 2026-11-20 (`yifuwuqi` live; `yirukou`, `yitaishi`, `yixiaoqing` via `ai-ssh`); Phase 0 in flight (qBittorrent stopgap in the working tree, not deployed)

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

| Host uid:gid | Resolves to        | Containers                                                                                          |
| ------------ | ------------------ | --------------------------------------------------------------------------------------------------- |
| 999:999      | `avahi`:`avahi`    | `firecrawl-postgres`, `firecrawl-rabbitmq`, `pinepods-db`                                           |
| 999:1000     | `avahi`:`yi`       | `firecrawl-redis`, `pinepods-valkey`                                                                |
| 999:952      | `avahi`:`media`    | `qbittorrent`                                                                                       |
| 1000:1000    | `yi`:`yi`          | `firecrawl-playwright` (image `User=node`; headless Chrome)                                         |
| 65534:65534  | `nobody`:`nogroup` | `flaresolverr` (Nix-built image)                                                                    |
| 100:101      | no account         | `pinepods` nginx worker                                                                             |
| 0:0          | `root`             | `cloudflared`, `firecrawl`, `gluetun`, `pinepods`, `slskd`, `soularr`, `torrent-indexer`, `weather` |

- Files written as 999: `pinepods-db`'s `PGDATA` under `/var/lib/container-volumes/pinepods/pgdata`, the qBittorrent config volume (17 entries), and 1545 entries in `/persist/media`.
- `cloudflared.nix` builds `user` from an unpinned account, so it renders `-u ':'` (nixpkgs `oci-containers.nix`) and the container runs as root. The image default is `65532:65532`, so the line escalates it. `localtonet.nix` and `playit-agent.nix` (not imported) repeat the pattern.
- `slskd.nix` gives `soularr` `PUID = "0"` and `PGID = "952"`, a literal copy of `media`'s dynamically allocated GID.
- Working tree, not deployed: `qbittorrent` becomes a dynamic system account in group `media`, and `preStart` writes its `PUID`/`PGID` to `/run/qbittorrent-ids.env`.
- No other host runs declared containers.

### Orphaned and reusable IDs on `yifuwuqi`

| Path                                      | Owner                             | Notes                                                                                                                                       |
| ----------------------------------------- | --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `/srv/webdav` (0775; nginx test files)    | uid 968, group `nginx`            | 968 is unrecorded, so the next new system account receives it: the pending `qbittorrent` account will be 968. `webdav.nix` is not imported. |
| `/srv/nfs/share` (0775; `latest.tar.zst`) | uid 1007 (no account), gid 967    | gid 967 is now `searx`, so the `searx` group can write here. NFS was removed 2026-03-21 (`a8ba048`).                                        |
| `/srv/nextcloud` (0750)                   | 975:972, retired `nextcloud`      | Recorded in the maps, so not reusable. The module is not imported.                                                                          |
| `/persist/media/podcasts` and one child   | uid 949, retired `audiobookshelf` | Recorded, not reusable. `pinepods` writes here as root.                                                                                     |

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

Phase 5 continues from 341.

## Phases

### Phase 0 — Finish the qBittorrent stopgap

1. Before or after deploying, as root: `chown root /srv/webdav`, so the new account does not keep the orphaned directory.
1. Deploy `yifuwuqi`, then as root (`su -`): `find /persist/media -xdev -uid 999 -exec chown -h qbittorrent {} +`. The unit's `preStart` re-owns the config volume.
1. Verify: `id -u qbittorrent` prints 968, `ps -o uid,gid,comm -C qbittorrent-nox` shows `968 952`, and `find /persist/media -xdev -uid 999` prints nothing.

### Phase 1 — Live audit

Extend `modules/services/monitoring/security-monitor/scripts/system-audit.sh` (root, every 15 minutes) with:

- `node_security_duplicate_ids{kind}`: IDs that appear twice in `/etc/passwd` or `/etc/group`.
- `node_security_container_shared_id{container,kind,name}`: a non-root container process whose host UID or GID resolves to an account or group other than that container's declared identity (its `user`, or `PUID`/`PGID` in `environment`). Nix renders the declared identities from `virtualisation.oci-containers.containers`.
- `node_security_container_root{container}`: a container process running as host root without a recorded reason.
- `node_security_unowned_files`: entries without an account or group, from `find / -xdev \( -path /nix -o -path /var/lib/containers \) -prune -o \( -nouser -o -nogroup \) -print`. All of `yifuwuqi`'s data, including `/persist` and `/srv`, lives on the root filesystem; image layers carry in-image IDs.

Add a panel to `modules/services/monitoring/dashboards/security.nix` and alert rules (non-zero for one hour) beside `modules/services/monitoring/rules/workloads.yml`. The root gauge stays dashboard-only until Phase 4 records the reasons. Expected first run on `yifuwuqi`: shared IDs for the 999, 1000 and 65534 rows (qBittorrent stays listed until Phase 4, because its IDs come from a runtime file), eight root containers, and non-zero unowned files from the orphan table.

### Phase 2 — Orphans, literals and shared groups

1. Apply the answers to Open questions 2–4: re-own or delete each orphan path as root, then rerun the audit.
1. Literal human IDs: geoclue `users` and the `yitaishi` NTFS options read `config.users.users.yi.uid` and `config.users.groups.yi.gid`. `nix-fix-uids.sh` takes its table from `users/users.nix` through `pkgs.writeShellApplication`, or is deleted.
1. Give `nix-builder` and `ai` their own dynamic groups (activation applies primary-group changes), then `chgrp -R nix-builder /var/lib/nix-builder` as root on each host.

### Phase 3 — Dedicated accounts for non-root containers

Declare accounts 333–339 from the ID table as `isSystemUser` with a same-numbered group, and set each container's `user` from them. The accounts are new, so activation creates them at the pinned numbers. Check each image before deploying:

| Container                            | Check                                                                                                                                                                                                  |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `pinepods-db`                        | Stop it, `chown -R pinepods-db:pinepods-db /var/lib/container-volumes/pinepods/pgdata`, start it. The official postgres image documents arbitrary `--user` support when `PGDATA` is owned by that UID. |
| `firecrawl-postgres`                 | `initdb` succeeds as the account. There is no host volume.                                                                                                                                             |
| `firecrawl-redis`, `pinepods-valkey` | `/data` is writable by the account (tmpfs mount) or snapshots are disabled. There is no host volume.                                                                                                   |
| `firecrawl-rabbitmq`                 | `/var/lib/rabbitmq` and its `.erlang.cookie` are writable by the account; the module already notes cookie-ownership failures.                                                                          |
| `firecrawl-playwright`               | Chrome gets a writable `HOME`.                                                                                                                                                                         |
| `flaresolverr`                       | Nothing to migrate (`HOME=/tmp`, no state).                                                                                                                                                            |

Verify: the shared-ID gauge only lists `qbittorrent`; the firecrawl readiness gates (`ExecStartPost` probes) and the Pinepods UI work.

### Phase 4 — Renumber existing accounts and land the contract

Configuration:

- `users.groups.media.gid = 330` and `users.users.qbittorrent.uid = 331`. qBittorrent's `PUID`/`PGID` move into `environment`, read from the account database; `/run/qbittorrent-ids.env` and its `preStart` lines go.
- `cloudflared` pinned to 332; its `user` then renders `332:332`.
- New `soularr` account (340, primary group `media`), read into `PUID`/`PGID`; its volume is owned `soularr:media`.
- A root-reason option on the container submodule in `modules/virtualisation/podman.nix`, set on `gluetun` and, until Phase 5, on the other root containers. The root alert turns on.
- Contract `container-identity` in `nix/checks.nix`, per host: each container has numeric `user` fields, numeric `PUID`/`PGID`, or a root reason; each UID and GID is pinned in 330–399 on a declared account or group; no two containers share a UID.

NixOS does not renumber existing accounts, so the window on `yifuwuqi` runs as root:

```bash
systemctl stop podman-qbittorrent podman-soularr podman-slskd podman-pinepods podman-cloudflared \
  radarr sonarr lidarr readarr bazarr jellyfin
groupmod -g 330 media
usermod -u 331 qbittorrent
groupmod -g 332 cloudflared
usermod -u 332 cloudflared
find / -xdev \( -path /nix -o -path /var/lib/containers \) -prune -o -gid 952 -exec chgrp -h media {} +
find / -xdev \( -path /nix -o -path /var/lib/containers \) -prune -o -uid 968 -exec chown -h qbittorrent {} +
find / -xdev \( -path /nix -o -path /var/lib/containers \) -prune -o \( -uid 984 -o -gid 979 \) -print
```

The last `find` should print nothing, since the `cloudflared` container has no volumes; re-own anything it lists. Then deploy and `systemctl start` the same units; units the switch already started are unaffected.

Verify: activation prints no `not applying` warning; `id qbittorrent` shows 331 and group 330; the shared-ID, duplicate-ID and unowned-file gauges read zero; `nix flake check --no-build` passes with the new contract.

### Phase 5 — De-root the remaining containers

One container per deploy (`slskd`, `torrent-indexer`, `firecrawl`, `pinepods`, `weather`): give it an account from 341 when the image runs unprivileged, otherwise replace its interim root reason with the real cause. `gluetun` keeps root. Then retire this plan.

## Rollout order

- [ ] **0.1** Re-own `/srv/webdav`, deploy `yifuwuqi`, re-own the 999 media files (User).
- [ ] **0.2** Verify the stopgap (AI).
- [ ] **1.1** Implement the audit gauges, panel and alerts; run fmt, lint and eval (AI).
- [ ] **1.2** Deploy every host (User); record the baseline from the textfile (AI).
- [ ] **2.1** Answer Open questions 2–4 (User).
- [ ] **2.2** Orphan cleanup (User); literal and group changes (AI); deploy (User).
- [ ] **3.1** Dedicated accounts and per-image checks (AI); deploy `yifuwuqi` (User); verify (AI).
- [ ] **4.1** Prepare the pinned configuration and the contract (AI).
- [ ] **4.2** Maintenance window: stop, renumber, sweep, deploy, start (User).
- [ ] **4.3** Verify: no activation warnings, audit at zero, contract passes (AI).
- [ ] **5.1** De-root containers, one per deploy (AI, User).
- [ ] **5.2** Retire this plan in the completing change set (AI).

Phase 1 lands first so every later step is measured. `/srv/webdav` must be re-owned before 4.2: renumbering `qbittorrent` releases 968 to the allocator again. Phases 3 and 4 touch the same host and can share one window; the contract lands with Phase 4 because it only passes then.

## Open questions

1. **User namespaces instead of host accounts?** `--userns=auto` would give each container a private ID range and also de-root the root containers. It needs subordinate ranges for the `containers` user, idmapped mounts for `media`-shared volumes, and proof that `--network=container:gluetun` works across user namespaces (otherwise that group becomes a pod). Default: no; reconsider in Phase 5 for whatever still needs root.
1. **Orphan data:** delete or keep `/srv/webdav` (nginx test files), `/srv/nfs` (one `latest.tar.zst`) and `/srv/nextcloud`? Re-own `/persist/media/podcasts` to `root:media`?
1. **`users/scripts/nix-fix-uids.sh`:** is it still needed? Its table duplicates `users/users.nix`.
1. **`localtonet.nix` and `playit-agent.nix`:** not imported, and both carry the `user = ":"` bug. Fix them with pinned accounts, or delete them?
1. **`yichuang`:** no `ai-ssh` access. Inventory it by hand, or wait until it joins the registry?
