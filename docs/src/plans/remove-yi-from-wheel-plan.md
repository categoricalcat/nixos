# Unprivileged Daily User (`yi`), Global Sudo Removal, & Client-Root→Server-Root Admin Lane

## Objective

Configure `yi` as a **completely unprivileged daily user account** with no
ambient root powers, **fully disable and remove `sudo` mesh-wide**, and
**restrict SOPS decryption strictly to `root`**, while establishing a secure,
explicit mechanism for the human operator to perform administrative work as `root`.

Root on servers will be reachable only through:

1. **Client-root → server-root SSH keys** (the sanctioned remote admin lane from client root),
1. **Tailscale SSH** (lockout rescue, operator identity only), and
1. **Physical console / boot break-glass**.

______________________________________________________________________

## Current State

All configuration and script changes are applied in the working tree on `develop`.

Deployment progress across the mesh:

- **`yixiaoqing` (Client)**: **[PENDING SWITCH]** Provisioned `/persist/keys/passwords/root` in Phase 2; ready to switch to the updated configuration.
- **`yitaishi` (Client)**: **[PENDING]** Needs Phase 2 (root password provisioning) and Phase 5 (switch).
- **`yifuwuqi` (Core Server)**: **[PENDING]** Awaiting Phase 4 deployment (`yi.ssh.permitRootKeyLogin = true` and `usermod -L root`).
- **`yirukou` (Perimeter Gateway)**: **[PENDING]** Awaiting Phase 4 deployment (`yi.ssh.permitRootKeyLogin = true` and `usermod -L root`).
- **Secrets (`secrets/secrets.yaml`)**: Pending Phase 3 rekeying (removing `yi` age recipients) and Phase 6 cleanup (removing `passwords/yi` and `passwords/workd` after all hosts have switched).

______________________________________________________________________

## Threat Model & Mechanics

The mesh = `yi`'s Per-Machine SSH allowlists + the read-only `ai` lane. Compromise of `yi`
must not grant `sudo`, `wheel`, SOPS decryption, or Nix daemon trust:

- **No wheel group**: `yi` is removed from `wheel`.
- **No sudo**: `security.sudo.enable = false;` removes the `/run/wrappers/bin/sudo` setuid wrapper and `/etc/sudoers` completely.
- **No SOPS access for `yi`**: `yi`'s keys are removed from `sopsAgeRecipients`. `/persist/keys/sops` is `0700 root:root` and `/persist/keys/sops/secrets.yaml` is `0600 root:root`. `SOPS_AGE_SSH_PRIVATE_KEY_FILE` points to `/persist/keys/ssh/ssh_host_ed25519_key` (`0600 root:root`). Only `root` can decrypt/edit `secrets.yaml`.
- **No local elevation on servers**: Servers have no root password configured (locked root password via `usermod -L root`), making `su -` impossible on servers.
- **Not trusted in Nix**: `nix.settings.trusted-users` contains only `["root" "nix-builder"]`. A trusted Nix user is root-equivalent (they can inject trusted substituters and drive the root daemon into executing arbitrary paths).
- **Operational trade-offs (`podman`/`docker` & Cockpit)**:
  - `yi` remains in `"podman"` and `"docker"` for daily container workflows (`docker` on clients and `cockpit-podman`/`cockpit-dockermanager` on `yifuwuqi`). Note that access to a rootful Docker/Podman socket is privileged on hosts where that socket is enabled.
  - On `yifuwuqi`, Cockpit web UI logins as `yi` operate in **Limited access** mode (since `yi` is not in `wheel`, `sudo` is disabled, and `root`'s password is locked on servers).

### Why `su -` is Unaffected by Disabling `sudo`

- `su` is provided by the `shadow` suite (`security.shadow` in NixOS) and authenticated via PAM (`/etc/pam.d/su`) against the **target** (`root`) user's password hash.
- `sudo` is a completely separate package (`security.sudo`) authenticated against the **caller** user and `/etc/sudoers`.
- Disabling `sudo` removes `sudo`, while `su -` remains fully functional.

### Why Root Password is Kept Out of SOPS

- Placing root's password inside SOPS introduces a circular recovery dependency (a SOPS failure locks you out of `su -`, but you need root to fix SOPS).
- Instead, root's password hash is placed directly in `/persist/keys/passwords/root` (`0600 root:root`) on clients.
- NixOS declares `users.users.root.hashedPasswordFile = "/persist/keys/passwords/root"` on clients and applies it via `/etc/shadow`, operating 100% independently of SOPS.
- Because `users.mutableUsers = true`, that declaration only seeds a freshly created
  account; on existing hosts the same hash is applied once with
  `usermod -p "$(cat /persist/keys/passwords/root)" root` (see Decision 3, Phase 2).

### Why Tailscale SSH and Client-Root SSH Work Without Server `su -`

- **Tailscale SSH**: Handled directly by `tailscaled`, which verifies the operator's Tailscale cryptographic identity against Tailscale ACLs and launches a root session directly (does not require passwords, `su`, or `sshd`).
- **Client-Root SSH**: The operator runs `su -` on a client (using the static root password file on `/persist/keys/passwords/root`), then runs `ssh root@server`. OpenSSH daemon on the server authenticates the client's host public key against `users.users.root.openssh.authorizedKeys`.

______________________________________________________________________

## Decisions

### 1. Global Sudo Removal & Polkit for GameMode

- \[`modules/common.nix`\](file:///home/yi/the.files/nixos/modules/common.nix): `security.sudo.enable = false;` globally across all hosts.
- \[`hosts/yitaishi/gaming.nix`\](file:///home/yi/the.files/nixos/hosts/yitaishi/gaming.nix): Replace `security.sudo.extraRules` with a declarative **Polkit rule** (`security.polkit.extraConfig`) allowing `yi` to start/stop `coolercontrold.service` and `lactd.service` without `sudo` or setuid wrappers. Update gamemode scripts to call `systemctl stop/start` directly.
- \[`modules/fido2.nix`\](file:///home/yi/the.files/nixos/modules/fido2.nix) & \[`hosts/yixiaoqing/configuration.nix`\](file:///home/yi/the.files/nixos/hosts/yixiaoqing/configuration.nix): Clean up obsolete `sudo` PAM options (`pam.services.sudo.u2fAuth`, `pam.services.sudo.fprintAuth`).
- \[`modules/services/tailscale.nix`\](file:///home/yi/the.files/nixos/modules/services/tailscale.nix): Update `tailscale-up` to invoke `tailscale up` directly (intended to run under root shell).

### 2. `yi` Unprivileged & SOPS Restricted Strictly to Root

- \[`users/users.nix`\](file:///home/yi/the.files/nixos/users/users.nix): Remove `"wheel"` from `users.users.yi.extraGroups`; drop the `hashedPasswordFile` references and SOPS password secrets for `yi`, `workd`, and `none` (passwords become mutable/operational — see Decision 7).
- \[`secrets/keys.nix`\](file:///home/yi/the.files/nixos/secrets/keys.nix): Remove `yi`'s age keys from `machines` and `sopsAgeRecipients`. Only the 4 host age recipients (`machine.host.age`) remain in `sopsAgeRecipients`.
- \[`secrets/sops.nix`\](file:///home/yi/the.files/nixos/secrets/sops.nix): Point `environment.variables.SOPS_AGE_SSH_PRIVATE_KEY_FILE` to `keys.paths.sshHostKey` (`/persist/keys/ssh/ssh_host_ed25519_key`). When `root` runs `sops`, it derives the age identity directly from the persisted host SSH key (even on impermanent `/root` tmpfs hosts like `yirukou`); unprivileged `yi` cannot read `/persist/keys/ssh/ssh_host_ed25519_key` (`0600 root:root`).
- \[`modules/packages/default.nix`\](file:///home/yi/the.files/nixos/modules/packages/default.nix): Include `ssh-to-age` alongside `sops` in base system packages.
- \[`hosts/yifuwuqi/configuration.nix`\](file:///home/yi/the.files/nixos/hosts/yifuwuqi/configuration.nix) & \[`hosts/yixiaoqing/configuration.nix`\](file:///home/yi/the.files/nixos/hosts/yixiaoqing/configuration.nix): Remove redundant `nix.settings.trusted-users = ["@wheel"]` overrides.
- \[`modules/nix-settings.nix`\](file:///home/yi/the.files/nixos/modules/nix-settings.nix): **Remove `"yi"` from `trusted-users`** (keep `["root" "nix-builder"]`). `yi` stays in `allowed-users`, which is sufficient to build flakes and query the store as a sandboxed user.
- \[`modules/nix-access-tokens.nix`\](file:///home/yi/the.files/nixos/modules/nix-access-tokens.nix): `group = "wheel"` → `"yi"` (read-only access to PAT fragment).
- \[`users/scripts/sops/setup.sh`\](file:///home/yi/the.files/nixos/users/scripts/sops/setup.sh), \[`sync-secrets.sh`\](file:///home/yi/the.files/nixos/users/scripts/sops/sync-secrets.sh), \[`ssh-pub-to-age.sh`\](file:///home/yi/the.files/nixos/users/scripts/sops/ssh-pub-to-age.sh), \[`derive-age-key.sh`\](file:///home/yi/the.files/nixos/users/scripts/sops/derive-age-key.sh), \[`ensure-ci-key.sh`\](file:///home/yi/the.files/nixos/users/scripts/sops/ensure-ci-key.sh):
  - Require running as root and `cd` to the repository root automatically.
  - `/persist/keys/sops` ownership `root:root` (`0700`) and `/persist/keys/sops/secrets.yaml` `root:root` (`0600`).
  - Drop all `yi` age key generation and actively delete any leftover `/home/yi/.config/sops/age/keys.txt`.
  - Pass `env HOME=/home/yi` whenever invoking `runuser -u yi -- nix ...` so `nix` never attempts to write to `/root/.cache/nix` (`Permission denied`).
  - Keep `/run/ci-deploy-key` owned by `root:root` (`0700`) in `ensure-ci-key.sh` so unprivileged `yi` cannot read the temporary CI root deployment key before ingestion.

### 3. Root Password via Static Hash File (Independent of SOPS)

- Root password is NOT stored in SOPS, preventing circular recovery lockouts if SOPS fails.
- `users.mutableUsers = true` globally (unchanged). NixOS only applies `*Password*` options when an account is **first created**, so `hashedPasswordFile` seeds fresh installs but is ignored for an existing root. Existing hosts must apply the hash operationally (Phase 2); `passwd` stays available for later changes.
- Generate salted hash on clients: `mkpasswd -m yescrypt > /persist/keys/passwords/root` (`0600 root:root`).
- On clients (`yixiaoqing`, `yitaishi`):
  `users.users.root.hashedPasswordFile = "/persist/keys/passwords/root";`
  (fresh-install seed) plus one-time application on existing hosts:
  `usermod -p "$(cat /persist/keys/passwords/root)" root`.
- On servers (`yifuwuqi`, `yirukou`): root has no `hashedPasswordFile`, and because the account already exists, lock it operationally with `usermod -L root` (declarative password options cannot lock an existing account under `mutableUsers`).

### 4. Client-root → server-root SSH (reusing host keys)

- **No new keys needed**: Root on clients (`yixiaoqing`, `yitaishi`) authenticates using each client's existing SSH host key (`/persist/keys/ssh/ssh_host_ed25519_key`), mirroring the `nix-builder` distributed build mesh pattern.
- \[`secrets/keys.nix`\](file:///home/yi/the.files/nixos/secrets/keys.nix): Authorize `machines.yitaishi.host.ssh` and `machines.yixiaoqing.host.ssh` in `rootAdmins` alongside `machines.yifuwuqi.host.ssh` and `ci.deployPublicKey` (perimeter gateway `yirukou` remains excluded from `rootAdmins`).
- \[`modules/services/ssh/default.nix`\](file:///home/yi/the.files/nixos/modules/services/ssh/default.nix):
  - Add option `yi.ssh.permitRootKeyLogin` (bool).
  - Servers (`yifuwuqi`, `yirukou`): `yi.ssh.permitRootKeyLogin = true;` sets `PermitRootLogin = "prohibit-password"`.
  - Clients (`yitaishi`, `yixiaoqing`): `PermitRootLogin = "no"` (with the Tailscale-only `Match User root Address ...` block retained when `permitRootKeyLogin` is `false`).
- \[`modules/services/ssh/dynamic.nix`\](file:///home/yi/the.files/nixos/modules/services/ssh/dynamic.nix): `Match localuser root User root` automatically uses `IdentityFile ${keys.paths.sshHostKey}` when `root` runs `ssh root@<server>`.

### 5. Tailscale SSH = lockout rescue (critical)

- Already enabled on `yifuwuqi` and `yirukou` (`yi.tailscale.ssh = true`).
  **Verify `tailscale ssh root@host` from a trusted device works before any sshd change.**
- Clients:
  - `yixiaoqing`: `yi.tailscale.ssh = true`.
  - `yitaishi`: `yi.tailscale.ssh = true`.
- Restrict the Tailscale ACL (admin console) to the operator's tailnet user/device only — otherwise any mesh host's identity could `tailscale ssh root@…`.

### 6. Root Home-Manager Shell & Git Safe-Directory

- \[`modules/home-manager.nix`\](file:///home/yi/the.files/nixos/modules/home-manager.nix), \[`users/home/root.nix`\](file:///home/yi/the.files/nixos/users/home/root.nix), \[`users/home/shell.nix`\](file:///home/yi/the.files/nixos/users/home/shell.nix), \[`users/home/common.nix`\](file:///home/yi/the.files/nixos/users/home/common.nix):
  - Extract shared shell, TUI, fastfetch, and neovim config into `users/home/shell.nix` (gating `EDITOR = "nvim"` / `VISUAL = "nvim"` on `config.serverMode.developer` so headless non-dev hosts like `yirukou` don't point `EDITOR` at an uninstalled binary).
  - Provision `root` with `users/home/root.nix`, including `.gitconfig` with `[safe] directory = *` and `gpgsign = false` so `root` never hits `libgit2`/`git` `detected dubious ownership` errors when running `nh` or `nix` inside `yi`-owned worktrees (`/home/yi/the.files/nixos`).
  - Guard \[`modules/desktop/gnome/home.nix`\](file:///home/yi/the.files/nixos/modules/desktop/gnome/home.nix) with `lib.mkIf (config.home.username != "root")`.

### 7. Mutable Passwords (SOPS Password Secrets Removed)

- Passwords are mutable and operational: Nix no longer defines the `passwords/yi` or `passwords/workd` SOPS secrets, and `yi`, `workd`, and `none` have no `hashedPasswordFile`.
- Existing accounts keep their current `/etc/shadow` hashes across the switch; a fresh install leaves them locked until set with `passwd`.
- The now-unused encrypted `passwords/yi` and `passwords/workd` entries are deleted from `secrets/secrets.yaml` with `sops` **in Phase 6 after all hosts have switched** (deleting them earlier breaks `sops-install-secrets.service` on any host still running the old manifest).

### 8. Dead `sudo` Tooling Cleanup

- \[`users/assets/dotfiles/zsh/aliases.zsh`\](file:///home/yi/the.files/nixos/users/assets/dotfiles/zsh/aliases.zsh): `nix-dr` becomes `nh os build .` (unprivileged build; no root).
- \[`users/assets/dotfiles/zsh/functions.zsh`\](file:///home/yi/the.files/nixos/users/assets/dotfiles/zsh/functions.zsh) & \[`users/assets/dotfiles/zsh/bindings.zsh`\](file:///home/yi/the.files/nixos/users/assets/dotfiles/zsh/bindings.zsh): remove the ESC-ESC `sudo`-insertion widget and its binding.
- \[`users/scripts/nix-sanity.sh`\](file:///home/yi/the.files/nixos/users/scripts/nix-sanity.sh): require root (`su -`); auto-`cd /home/yi/the.files/nixos` when invoked from `/root`; run `yi`-owned steps (`nix fmt`, `statix`, `deadnix`, `git add`, `nix flake check`) via `runuser -u yi -- env HOME=/home/yi`.
- \[`users/scripts/nix-fix-uids.sh`\](file:///home/yi/the.files/nixos/users/scripts/nix-fix-uids.sh): root-gated message now points at `su -`.
- \[`users/scripts/wipe-attic-cache.sh`\](file:///home/yi/the.files/nixos/users/scripts/wipe-attic-cache.sh) & \[`packages/wipe-attic-cache.nix`\](file:///home/yi/the.files/nixos/packages/wipe-attic-cache.nix): require root (`su -`); invoke `systemctl`/`test`/`find` directly and run `psql` as `postgres` via `runuser -u postgres --` (`util-linux` added to `runtimeInputs`).
- `hosts/yitaishi/fanatec/*.env`: apply hint now reads "as root (`su -`)".
- `users/programs/opencode.nix` keeps its `"sudo*" = "deny"` rule (now inert but harmless).

______________________________________________________________________

## Workflows

| Task                         | How                                                                   |
| ---------------------------- | --------------------------------------------------------------------- |
| Admin a server from a client | client TTY → `su -` (root pw) → `ssh root@yifuwuqi` → `nh os switch`  |
| Admin a client locally       | client TTY → `su -` → `nh os switch`                                  |
| Change a user password       | `passwd` (mutable; passwords are no longer managed by Nix or SOPS)    |
| Rescue (broken sshd/keys)    | `tailscale ssh root@host` from trusted device                         |
| Edit SOPS secrets            | client TTY → `su -` → `sops secrets/secrets.yaml` (uses host SSH key) |
| Server local isolation       | `yi` on server cannot `sudo`, `su -`, or decrypt SOPS                 |

______________________________________________________________________

## Phases & Rollout Order (lockout-safe)

### Phase 1: Pre-Switch Rescue Verification (Out-of-Band)

1. **Verify Tailscale SSH root login to servers** from an authenticated operator device before switching any configurations:
   ```bash
   tailscale ssh root@yifuwuqi
   tailscale ssh root@yirukou
   ```
   *Checkpoint*: Ensure you obtain an interactive root prompt without requiring a password. If Tailscale SSH fails, resolve Tailscale ACLs before touching sshd or sudo.

### Phase 2: Static Root Password Provisioning on Clients

2. On each client machine, create the persistent root password hash file **before** switching (using the still-present `sudo` where available), and apply it:
   - **`yixiaoqing`**: **[COMPLETED]** Root password hash generated and applied in `/persist/keys/passwords/root`.
   - **`yitaishi`**: **[PENDING]** Execute before removing sudo:
     ```bash
     sudo install -d -m 0700 -o root -g root /persist/keys/passwords
     mkpasswd -m yescrypt | sudo tee /persist/keys/passwords/root > /dev/null
     sudo chmod 0600 /persist/keys/passwords/root
     sudo usermod -p "$(sudo cat /persist/keys/passwords/root)" root
     ```
   *Checkpoint*: Test elevation into root locally using `su -` with the newly minted password.

### Phase 3: SOPS Rekeying & Secrets Sync

3. First, run `setup-sops.sh` as root so `.sops.yaml` is regenerated with only the 4 host age recipients (`sopsAgeRecipients`), `/home/yi/.config/sops/age/keys.txt` is deleted, and `/persist/keys/sops` permissions (`0700 root:root`) are enforced:
   ```bash
   su -
   cd /home/yi/the.files/nixos
   ./users/scripts/setup-sops.sh
   ```
1. Rekey `secrets/secrets.yaml` against the updated `.sops.yaml` so only host age recipients can decrypt (pass `SOPS_AGE_SSH_PRIVATE_KEY_FILE` explicitly if the host has not switched yet, because the pre-switch environment still points it at `/home/yi/.ssh/id_ed25519`):
   ```bash
   SOPS_AGE_SSH_PRIVATE_KEY_FILE=/persist/keys/ssh/ssh_host_ed25519_key \
     sops updatekeys -y secrets/secrets.yaml
   ```
1. Sync the rekeyed `secrets/secrets.yaml` to `/persist/keys/sops/secrets.yaml` (`0600 root:root`) on each host:
   ```bash
   ./users/scripts/setup-sops.sh
   ```
   *(Do **not** delete `passwords/yi` or `passwords/workd` from `secrets/secrets.yaml` yet — wait until Phase 6 after all hosts have switched so `sops-install-secrets.service` never fails on an unswitched host.)*

### Phase 4: Server Deployment & Admin Lane Verification

6. Switch server configurations (`yifuwuqi`, `yirukou`) to enable `yi.ssh.permitRootKeyLogin` and authorize client host keys in `root`'s `authorized_keys`:
   ```bash
   # On yifuwuqi / yirukou (as root via su - or ssh root@<server>):
   nh os switch /home/yi/the.files/nixos
   # Or from a root shell on an authorized host:
   cd /home/yi/the.files/nixos && deploy .#yifuwuqi && deploy .#yirukou
   ```
1. Lock root on each server (declarative password options cannot lock an existing account under `mutableUsers`):
   ```bash
   # On yifuwuqi / yirukou (as root):
   usermod -L root
   ```
1. **Verify the client-root → server-root admin lane**:
   - On a provisioned client (`yixiaoqing` or `yitaishi`), elevate to root via `su -`:
     ```bash
     su -
     ssh root@yifuwuqi
     ```
   - *Checkpoint*: Confirm the client host key automatically authenticates and drops into a root shell on `yifuwuqi`.
   - *Negative Check*: Confirm unprivileged `yi` on client cannot SSH to `root@yifuwuqi` (`ssh root@yifuwuqi` as `yi` fails).

### Phase 5: Client Deployment & Sudo Removal

9. Switch client configurations (`yixiaoqing`, `yitaishi`):
   ```bash
   # On yixiaoqing / yitaishi as root:
   su -
   nh os switch /home/yi/the.files/nixos
   ```

### Phase 6: Post-Deployment SOPS Password Cleanup & Mesh-Wide Validation

10. Now that all hosts have switched and no host's `sops-nix` manifest references `passwords/yi` or `passwords/workd`, remove those entries from `secrets/secrets.yaml` and sync:
    ```bash
    su -
    cd /home/yi/the.files/nixos
    sops secrets/secrets.yaml   # remove the `passwords` block (`yi` and `workd`)
    ./users/scripts/setup-sops.sh
    ```
01. Validate all hosts against the security checklist:

- **No sudo**: `sudo id` returns `command not found`.
- **No wheel**: `id yi` does not list group `wheel`.
- **No local elevation on servers**: On `yifuwuqi` and `yirukou`, `su -` fails with `Authentication failure` (locked via `usermod -L root`).
- **Local elevation on clients**: On `yitaishi` and `yixiaoqing`, `su -` succeeds with the password minted in Phase 2.
- **Mutable passwords**: `secrets/secrets.yaml` no longer contains `passwords/yi` or `passwords/workd`, and `passwd` can change user passwords.
- **Root-only SOPS**: As user `yi`, attempting to read `/persist/keys/sops/secrets.yaml` or run `sops secrets/secrets.yaml` fails; as `root` (`su -`), `sops secrets/secrets.yaml` opens cleanly using `/persist/keys/ssh/ssh_host_ed25519_key`.
- **Nix daemon trust**: As user `yi`, `nix show-config | grep trusted-users` shows only `root nix-builder`.
- **GameMode Polkit rule**: On `yitaishi`, GameMode systemd service toggles (`coolercontrold.service`, `lactd.service`) succeed as `yi` without sudo or password prompts.
- **Tailscale SSH rescue**: Tailscale SSH to root continues to function across all nodes.

______________________________________________________________________

## Files Touched

- \[`modules/common.nix`\](file:///home/yi/the.files/nixos/modules/common.nix): Disable sudo globally (`security.sudo.enable = false;`).
- \[`users/users.nix`\](file:///home/yi/the.files/nixos/users/users.nix): Remove `wheel`; drop SOPS password secrets and `hashedPasswordFile` for `yi`/`workd`/`none`; add `root` `hashedPasswordFile` seed on clients.
- \[`secrets/keys.nix`\](file:///home/yi/the.files/nixos/secrets/keys.nix): Remove `yi` age keys from `machines` and `sopsAgeRecipients`; authorize client host keys (`yitaishi`, `yixiaoqing`) in `rootAdmins`.
- \[`secrets/sops.nix`\](file:///home/yi/the.files/nixos/secrets/sops.nix): Point `SOPS_AGE_SSH_PRIVATE_KEY_FILE` at `keys.paths.sshHostKey`.
- \[`modules/packages/default.nix`\](file:///home/yi/the.files/nixos/modules/packages/default.nix): Add `ssh-to-age` alongside `sops`.
- \[`hosts/yitaishi/gaming.nix`\](file:///home/yi/the.files/nixos/hosts/yitaishi/gaming.nix): Polkit rule for `coolercontrold` / `lactd`.
- \[`hosts/yitaishi/fanatec/ams2.env`\](file:///home/yi/the.files/nixos/hosts/yitaishi/fanatec/ams2.env) & \[`beamng.env`\](file:///home/yi/the.files/nixos/hosts/yitaishi/fanatec/beamng.env): Update apply comment to `as root (su -)`.
- \[`modules/fido2.nix`\](file:///home/yi/the.files/nixos/modules/fido2.nix): Clean up sudo PAM options.
- \[`users/scripts/sops/setup.sh`\](file:///home/yi/the.files/nixos/users/scripts/sops/setup.sh), \[`sync-secrets.sh`\](file:///home/yi/the.files/nixos/users/scripts/sops/sync-secrets.sh), \[`ssh-pub-to-age.sh`\](file:///home/yi/the.files/nixos/users/scripts/sops/ssh-pub-to-age.sh), \[`derive-age-key.sh`\](file:///home/yi/the.files/nixos/users/scripts/sops/derive-age-key.sh), \[`ensure-ci-key.sh`\](file:///home/yi/the.files/nixos/users/scripts/sops/ensure-ci-key.sh): Root-only enforcement, `0700`/`0600` `root:root` permissions, `env HOME=/home/yi` for `runuser`, stale `yi` age key removal, and `root:root` ownership for `/run/ci-deploy-key`.
- \[`modules/nix-settings.nix`\](file:///home/yi/the.files/nixos/modules/nix-settings.nix): Remove `yi` from `nix.settings.trusted-users`.
- \[`modules/nix-access-tokens.nix`\](file:///home/yi/the.files/nixos/modules/nix-access-tokens.nix): Change group from `wheel` to `yi`.
- \[`modules/services/ssh/default.nix`\](file:///home/yi/the.files/nixos/modules/services/ssh/default.nix): Option `yi.ssh.permitRootKeyLogin` and server `PermitRootLogin = "prohibit-password"`.
- \[`modules/services/tailscale.nix`\](file:///home/yi/the.files/nixos/modules/services/tailscale.nix): Cleanup `tailscale-up` wrapper.
- \[`hosts/yifuwuqi/configuration.nix`\](file:///home/yi/the.files/nixos/hosts/yifuwuqi/configuration.nix): Remove redundant `trusted-users = ["@wheel"]`; enable `yi.ssh.permitRootKeyLogin = true`.
- \[`hosts/yixiaoqing/configuration.nix`\](file:///home/yi/the.files/nixos/hosts/yixiaoqing/configuration.nix): Remove redundant `trusted-users = ["@wheel"]` and sudo PAM config; enable `yi.tailscale.ssh = true`.
- \[`hosts/yitaishi/configuration.nix`\](file:///home/yi/the.files/nixos/hosts/yitaishi/configuration.nix): Enable `yi.tailscale.ssh = true`.
- \[`hosts/yirukou/configuration.nix`\](file:///home/yi/the.files/nixos/hosts/yirukou/configuration.nix): Enable `yi.ssh.permitRootKeyLogin = true`.
- \[`modules/home-manager.nix`\](file:///home/yi/the.files/nixos/modules/home-manager.nix), \[`users/home/common.nix`\](file:///home/yi/the.files/nixos/users/home/common.nix), \[`users/home/shell.nix`\](file:///home/yi/the.files/nixos/users/home/shell.nix), \[`users/home/root.nix`\](file:///home/yi/the.files/nixos/users/home/root.nix), \[`modules/desktop/gnome/home.nix`\](file:///home/yi/the.files/nixos/modules/desktop/gnome/home.nix), \[`users/assets/dotfiles/gitconfig`\](file:///home/yi/the.files/nixos/users/assets/dotfiles/gitconfig): Shared shell config and `root` Home-Manager profile with `safe.directory`.
- \[`users/assets/dotfiles/zsh/aliases.zsh`\](file:///home/yi/the.files/nixos/users/assets/dotfiles/zsh/aliases.zsh), \[`functions.zsh`\](file:///home/yi/the.files/nixos/users/assets/dotfiles/zsh/functions.zsh), \[`bindings.zsh`\](file:///home/yi/the.files/nixos/users/assets/dotfiles/zsh/bindings.zsh): Dead sudo tooling cleanup.
- \[`users/scripts/nix-sanity.sh`\](file:///home/yi/the.files/nixos/users/scripts/nix-sanity.sh), \[`users/scripts/nix-fix-uids.sh`\](file:///home/yi/the.files/nixos/users/scripts/nix-fix-uids.sh), \[`users/scripts/wipe-attic-cache.sh`\](file:///home/yi/the.files/nixos/users/scripts/wipe-attic-cache.sh), \[`packages/wipe-attic-cache.nix`\](file:///home/yi/the.files/nixos/packages/wipe-attic-cache.nix): Root-only and `runuser` adjustments.
- \[`docs/src/services/secrets.md`\](file:///home/yi/the.files/nixos/docs/src/services/secrets.md), \[`docs/src/hardware/bootstrap-runbook.md`\](file:///home/yi/the.files/nixos/docs/src/hardware/bootstrap-runbook.md), \[`docs/src/hardware/bootstrap.md`\](file:///home/yi/the.files/nixos/docs/src/hardware/bootstrap.md), \[`docs/src/services/nix-build-cache.md`\](file:///home/yi/the.files/nixos/docs/src/services/nix-build-cache.md), \[`docs/src/services/ci-cd.md`\](file:///home/yi/the.files/nixos/docs/src/services/ci-cd.md), \[`docs/src/services/ci-cache.md`\](file:///home/yi/the.files/nixos/docs/src/services/ci-cache.md), \[`docs/src/services/ai-ssh.md`\](file:///home/yi/the.files/nixos/docs/src/services/ai-ssh.md), \[`docs/src/hosts/yitaishi.md`\](file:///home/yi/the.files/nixos/docs/src/hosts/yitaishi.md), \[`docs/src/hosts/yixiaoqing.md`\](file:///home/yi/the.files/nixos/docs/src/hosts/yixiaoqing.md), \[`docs/src/networking/unbound-integration.md`\](file:///home/yi/the.files/nixos/docs/src/networking/unbound-integration.md), \[`docs/src/networking/tailscale-subnet-forwarding.md`\](file:///home/yi/the.files/nixos/docs/src/networking/tailscale-subnet-forwarding.md): Update documentation across the gang book for root-only SOPS, `su -` workflows, client root password provisioning, and `sudo` removal.

______________________________________________________________________

## Open Questions

- None — decisions locked.
