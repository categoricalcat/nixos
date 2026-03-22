# Plan: Refactor Podman and Container Management on `yifuwuqi`

## Objective
Decouple container management from host-specific service files to improve organization and reusability. This involves moving Podman configurations to a dedicated module, establishing structured storage for volumes, and implementing a custom container network to move away from the default bridge.

## 1. Create Dedicated Module: `modules/virtualisation/podman.nix`
This new module will centralize all container-related infrastructure:
- **Backend:** Set `virtualisation.oci-containers.backend = "podman";`.
- **Podman Settings:** Move `virtualisation.podman` (socket, autoPrune, network settings) and `virtualisation.containers` (storage, registries, containersConf) here.
- **Dedicated Storage:** Add `systemd.tmpfiles.rules` to create `/var/lib/container-volumes` with appropriate permissions (e.g., `0770 root podman`).
- **Dedicated Network:** Add a systemd service (`podman-network-app-net`) that runs `podman network create app-net` if it doesn't exist. This ensures containers can be isolated from the default `podman0` bridge.
- **Tools & Groups:** Move container CLI tools (`buildah`, `skopeo`, etc.) and the `workd` user's `podman` group assignment here.

## 2. Refactor `hosts/yifuwuqi/services.nix`
- Remove all `virtualisation.podman`, `virtualisation.containers`, and `environment.systemPackages` related to containers.
- Remove the `users.users.workd.extraGroups = [ "podman" ];` assignment.
- (Optional) Update individual service containers (like Joplin or Cloudflared) to use the new volume path and network, though this can be done incrementally.

## 3. Update `hosts/yifuwuqi/configuration.nix`
- Add `../../modules/virtualisation/podman.nix` to the `imports` list.

## Verification Steps
1. **Syntax Check:** Run `nix-instantiate --parse` on the new and modified files.
2. **Dry Activation:** Run `sudo nixos-rebuild dry-activate --flake .#yifuwuqi` to check for configuration conflicts.
3. **Network/Storage Validation:** After deployment, verify:
   - `/var/lib/container-volumes` exists.
   - `podman network inspect app-net` returns the new network configuration.
