# Podman Volume Migration & Database Fix Plan

## The Problem
When running rootless Podman commands (like `podman ps`), the system throws a database configuration mismatch error:
```
Error: database static dir "/home/fufud/.local/share/containers/storage/libpod" does not match our static dir "/home/yi/.local/share/containers/storage/libpod"
```
This occurred because the home directory was migrated from `/home/fufud` to `/home/yi`, but Podman's internal SQLite/BoltDB configuration database (`bolt_state.db`) still contains hardcoded absolute paths pointing to the old `fufud` username.

## Analysis of Existing Data
1. **NixOS Managed Containers (Rootful):** All containers managed by your NixOS configuration (Firecrawl, Cloudflared, Portainer, etc.) run as rootful containers. Their data is safely stored in `/var/lib/containers` and is completely unaffected by this mismatch.
2. **Rootless Volumes:** I inspected `~/.local/share/containers/storage/volumes/` and confirmed it is **completely empty**. There are no managed anonymous volumes containing data for the rootless user.
3. **Legacy Rootless Containers:** There are 5 legacy rootless containers still existing inside `~/.local/share/containers/storage/overlay-containers`. Because the volumes directory is empty, any "important data" associated with these containers is either:
   - Residing in bind-mounted host directories (which are already safe in `/home/yi/`).
   - Stored directly inside the container's read-write overlay layers.

## Migration Steps

Since we cannot easily run `podman` commands against the broken database, the safest approach is to backup the old state and initialize a fresh one for the `yi` user. 

### Step 1: Backup the Legacy State
Instead of deleting the data, we will move it safely out of the way. This preserves all the overlay layers in case we discover a missing file later that was trapped inside a container's filesystem.
```bash
mv ~/.local/share/containers ~/.local/share/containers_fufud_legacy_backup
```

### Step 2: Initialize Fresh Rootless Podman
Trigger Podman to generate a brand new, correctly configured database for the `yi` user.
```bash
podman info
```
This command will recreate `~/.local/share/containers` natively pointing to `/home/yi/`. `podman ps` will now work perfectly without sudo.

### Step 3: Data Recovery (If Needed)
If you realize a specific legacy rootless container had important files stored directly inside its filesystem (not in a bind mount), the data is still perfectly safe inside `~/.local/share/containers_fufud_legacy_backup/storage/overlay/`. 
You can use standard `grep` and `find` commands against that backup directory to extract any files. Once you are confident no data is missing, you can permanently delete the backup folder to free up space.
