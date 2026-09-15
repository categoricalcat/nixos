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

The code changes implementing this architecture across 34 files are preserved in git stash (`stash@{0}: On develop: wheel`).

Deployment progress across the mesh:

- **`yixiaoqing` (Client)**: **[APPLIED]** Already running the unprivileged `yi` configuration. Sudo is disabled, `yi` is removed from `wheel`, `/etc/nix/nix.conf` trusted-users is restricted to `root nix-builder`, and root elevation via `su -` is authenticated using `/persist/keys/passwords/root`. It acts as the first deployed canary and can be used immediately to verify the client-root → server-root SSH lane once servers are switched.
- **`yitaishi` (Client)**: **[PENDING]** Still retains `wheel`, `sudo`, and declarative password bindings. Needs Phase 2 (root password provisioning) and Phase 5 (switch).
- **`yifuwuqi` (Core Server)**: **[PENDING]** Still has `sudo` enabled. Awaiting Phase 4 deployment (`yi.ssh.permitRootKeyLogin` and `usermod -L root`).
- **`yirukou` (Perimeter Gateway)**: **[PENDING]** Still has `sudo` enabled. Awaiting Phase 4 deployment.
- **Secrets (`secrets/secrets.yaml`)**: Still contains `passwords/yi` and `passwords/workd`. Pending Phase 3 rekeying.

______________________________________________________________________

## Threat Model & Mechanics

The mesh = `yi`'s N×N ssh keys + the read-only `ai` lane. Mesh compromise
yields `yi` on every host. Therefore `yi` must have **zero root and zero secrets access**:

- **No wheel group**: `yi` has no administrative group memberships.
- **No sudo**: `security.sudo.enable = false;` removes the `/run/wrappers/bin/sudo` setuid wrapper and `/etc/sudoers` completely.
- **No SOPS access for `yi`**: `yi`'s keys are removed from `sopsAgeRecipients`. `/persist/keys/sops` is `0700 root:root`. Only `root` can decrypt/edit `secrets.yaml`.
- **No local elevation on servers**: Servers have no root password configured (locked root password), making `su -` impossible on servers.
- **Not trusted in Nix**: `nix.settings.trusted-users` contains only `["root" "nix-builder"]`. A trusted Nix user is root-equivalent (they can inject trusted substituters and drive the root daemon into executing arbitrary paths).

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

### 2. `yi` fully unprivileged & SOPS Restricted to Root

- \[`users/users.nix`\](file:///home/yi/the.files/nixos/users/users.nix): Remove `"wheel"` from `users.users.yi.extraGroups`; drop the `hashedPasswordFile` references and SOPS password secrets for `yi`, `workd`, and `none` (passwords become mutable/operational — see Decision 7).
- \[`secrets/keys.nix`\](file:///home/yi/the.files/nixos/secrets/keys.nix): Remove all `users.yi.meshKeys.*.ageRecipient` from `sopsAgeRecipients`. Only `hosts.<host>.ageRecipient` remain.
- \[`secrets/sops.nix`\](file:///home/yi/the.files/nixos/secrets/sops.nix): Remove `SOPS_AGE_SSH_PRIVATE_KEY_FILE` environment variable pointing to `yi`'s home.
- \[`hosts/yifuwuqi/configuration.nix`\](file:///home/yi/the.files/nixos/hosts/yifuwuqi/configuration.nix) & \[`hosts/yixiaoqing/configuration.nix`\](file:///home/yi/the.files/nixos/hosts/yixiaoqing/configuration.nix): Remove redundant `nix.settings.trusted-users = ["@wheel"]` overrides.
- \[`modules/nix-settings.nix`\](file:///home/yi/the.files/nixos/modules/nix-settings.nix): **Remove `"yi"` from `trusted-users`** (keep `["root" "nix-builder"]`). `yi` stays in `allowed-users`, which is sufficient to build flakes and query the store as a sandboxed user. All binary caches are configured globally, so `yi` loses nothing functional.
- \[`modules/nix-access-tokens.nix`\](file:///home/yi/the.files/nixos/modules/nix-access-tokens.nix): `group = "wheel"` → `"yi"` (read-only access to PAT fragment).
- \[`users/scripts/sops/setup.sh`\](file:///home/yi/the.files/nixos/users/scripts/sops/setup.sh):
  - `/persist/keys/sops` ownership `root:root` (`0700`).
  - Drop all `yi` age key generation.
  - Require running as root; replace `sudo -u yi` with `runuser -u yi --`.

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
- \[`secrets/keys.nix`\](file:///home/yi/the.files/nixos/secrets/keys.nix): unchanged for host keys — `hosts.<client>.sshPublicKey` is already registered.
- Servers (`yifuwuqi`, `yirukou`): `users.users.root.openssh.authorizedKeys` is a global list and already contains the client host keys (`keys.hosts.yixiaoqing.sshPublicKey`, `keys.hosts.yitaishi.sshPublicKey`), plus `keys.hosts.yifuwuqi.sshPublicKey` and `keys.ci.deployPublicKey` (unchanged).
- \[`modules/services/ssh/default.nix`\](file:///home/yi/the.files/nixos/modules/services/ssh/default.nix):
  - Add option `yi.ssh.permitRootKeyLogin` (bool).
  - Servers: `PermitRootLogin = "prohibit-password"` (root is already present in `AllowUsers`; only the login mode needs to change).
  - Clients: `PermitRootLogin = "no"` (unchanged).
  - Add OpenSSH client match block to `programs.ssh.extraConfig` via \[`modules/services/ssh/dynamic.nix`\](file:///home/yi/the.files/nixos/modules/services/ssh/dynamic.nix) so `su -` → `ssh root@<server>` automatically uses the host key:
    ```ssh
    Match User root
        IdentityFile ${keys.paths.sshHostKey}
    ```

### 5. Tailscale SSH = lockout rescue (critical)

- Already enabled on yifuwuqi and yirukou (`yi.tailscale.ssh = true`).
  **Verify `tailscale ssh root@host` from a trusted device works before any sshd change.**
- Clients:
  - yixiaoqing: `yi.tailscale.ssh = true`.
  - yitaishi: set `yi.tailscale.ssh = true`. The tailscale module is already imported via `hosts/yitaishi/services.nix` (it was never commented out).
- Restrict the Tailscale ACL (admin console) to the operator's tailnet user/device only — otherwise any mesh host's identity could `tailscale ssh root@…`.

### 6. Unchanged

- `yi` stays in `nix.settings.allowed-users` (flake builds without root).
- `ai` read-only user and gate unchanged.
- `yi` mesh keys stay for daily inter-host use.

### 7. Mutable Passwords (SOPS Password Secrets Removed)

- Passwords are mutable and operational: Nix no longer defines the `passwords/yi` or `passwords/workd` SOPS secrets, and `yi`, `workd`, and `none` have no `hashedPasswordFile`.
- Existing accounts keep their current `/etc/shadow` hashes across the switch; a fresh install leaves them locked until set with `passwd`.
- The now-unused encrypted `passwords/yi` and `passwords/workd` entries are deleted from `secrets/secrets.yaml` with `sops` (operator step, Phase 3).

### 8. Dead `sudo` Tooling Cleanup

- \[`users/assets/dotfiles/zsh/aliases.zsh`\](file:///home/yi/the.files/nixos/users/assets/dotfiles/zsh/aliases.zsh): `nix-dr` becomes `nh os build .` (unprivileged build; no root).
- \[`users/assets/dotfiles/zsh/functions.zsh`\](file:///home/yi/the.files/nixos/users/assets/dotfiles/zsh/functions.zsh) & \[`users/assets/dotfiles/zsh/bindings.zsh`\](file:///home/yi/the.files/nixos/users/assets/dotfiles/zsh/bindings.zsh): remove the ESC-ESC `sudo`-insertion widget and its binding.
- \[`users/scripts/nix-sanity.sh`\](file:///home/yi/the.files/nixos/users/scripts/nix-sanity.sh): require root (`su -`); run `yi`-owned steps (`nix fmt`, `statix`, `deadnix`, `git add`, `nix flake check`) via `runuser -u yi`.
- \[`users/scripts/nix-fix-uids.sh`\](file:///home/yi/the.files/nixos/users/scripts/nix-fix-uids.sh): root-gated message now points at `su -`.
- \[`users/scripts/wipe-attic-cache.sh`\](file:///home/yi/the.files/nixos/users/scripts/wipe-attic-cache.sh): root-only; calls `systemctl`/`systemd-run` directly and runs `attic` as `yi` via `runuser`.
- `hosts/yitaishi/fanatec/*.env`: apply hint now reads "as root (`su -`)".
- `users/programs/opencode.nix` keeps its `"sudo*" = "deny"` rule (now inert but harmless).

______________________________________________________________________

## Workflows

| Task                         | How                                                                    |
| ---------------------------- | ---------------------------------------------------------------------- |
| Admin a server from a client | client TTY → `su -` (root pw) → `ssh root@yifuwuqi` → `nh os switch .` |
| Admin a client locally       | client TTY → `su -` → `nh os switch .`                                 |
| Change a user password       | `passwd` (mutable; passwords are no longer managed by Nix or SOPS)     |
| Rescue (broken sshd/keys)    | `tailscale ssh root@host` from trusted device                          |
| Edit SOPS secrets            | client TTY → `su -` → `sops secrets/secrets.yaml` (using host key)     |
| Server local isolation       | `yi` on server cannot `sudo`, `su -`, or decrypt SOPS                  |

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

3. Rekey `secrets/secrets.yaml` so only host age recipients (`sopsAgeRecipients`) can decrypt:
   ```bash
   # Run as root on client (using host SSH key):
   su -
   cd /home/yi/the.files/nixos
   SOPS_AGE_SSH_PRIVATE_KEY_FILE=/persist/keys/ssh/ssh_host_ed25519_key \
     nix-shell -p sops --run 'sops updatekeys -y secrets/secrets.yaml'
   ```
1. Run the SOPS setup script to refresh runtime permissions (`/persist/keys/sops` 0700 root:root) and sync encrypted payloads:
   ```bash
   # As root:
   ./users/scripts/setup-sops.sh
   ```
1. Delete the now-unused password secrets from the encrypted file (as root):
   ```bash
   sops secrets/secrets.yaml   # remove the `passwords/yi` and `passwords/workd` entries
   ```

### Phase 4: Server Deployment & Admin Lane Verification

6. Switch server configurations (`yifuwuqi`, `yirukou`) to enable `yi.ssh.permitRootKeyLogin`:
   ```bash
   # On yifuwuqi / yirukou:
   nh os switch .
   ```
1. Lock root on each server (declarative password options cannot lock an existing account under `mutableUsers`):
   ```bash
   # On yifuwuqi / yirukou:
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

9. Switch client configurations (`yitaishi`, `yixiaoqing`):
   - **`yixiaoqing`**: **[COMPLETED]** Configuration already switched and running.
   - **`yitaishi`**: **[PENDING]**
     ```bash
     # On yitaishi as root:
     su -
     nh os switch .
     ```

### Phase 6: Post-Deployment Validation Mesh-Wide

10. Validate all hosts against the security checklist:

- **No sudo**: `sudo id` returns `command not found`.
- **No wheel**: `id yi` does not list group `wheel`.
- **No local elevation on servers**: On `yifuwuqi` and `yirukou`, `su -` fails with `Authentication failure` (locked via `usermod -L root`).
- **Local elevation on clients**: On `yitaishi` and `yixiaoqing`, `su -` succeeds with the password minted in Phase 2.
- **Mutable passwords**: `secrets/secrets.yaml` no longer contains `passwords/yi` or `passwords/workd`, and `passwd` can change user passwords.
- **Root-only SOPS**: As user `yi`, attempting to read `/persist/keys/sops/secrets.yaml` or decrypt SOPS fails.
- **Nix daemon trust**: As user `yi`, `nix show-config | grep trusted-users` shows only `root nix-builder`.
- **GameMode Polkit rule**: On `yitaishi`, GameMode systemd service toggles (`coolercontrold.service`, `lactd.service`) succeed as `yi` without sudo or password prompts.
- **Tailscale SSH rescue**: Tailscale SSH to root continues to function across all nodes.

______________________________________________________________________

## Files Touched

- \[`modules/common.nix`\](file:///home/yi/the.files/nixos/modules/common.nix): Disable sudo globally (`security.sudo.enable = false;`).
- \[`users/users.nix`\](file:///home/yi/the.files/nixos/users/users.nix): Remove `wheel`; drop SOPS password secrets and `hashedPasswordFile` for `yi`/`workd`/`none`; keep the root `hashedPasswordFile` seed on clients.
- \[`secrets/keys.nix`\](file:///home/yi/the.files/nixos/secrets/keys.nix): Remove `yi` meshKeys from `sopsAgeRecipients`.
- \[`secrets/sops.nix`\](file:///home/yi/the.files/nixos/secrets/sops.nix): Remove `SOPS_AGE_SSH_PRIVATE_KEY_FILE` environment variables pointing to `yi`'s home.
- \[`hosts/yitaishi/gaming.nix`\](file:///home/yi/the.files/nixos/hosts/yitaishi/gaming.nix): Polkit rule for `coolercontrold` / `lactd`.
- \[`modules/fido2.nix`\](file:///home/yi/the.files/nixos/modules/fido2.nix): Clean up sudo PAM options.
- \[`users/scripts/setup-sops.sh`\](file:///home/yi/the.files/nixos/users/scripts/setup-sops.sh) & \[`users/scripts/sops/setup.sh`\](file:///home/yi/the.files/nixos/users/scripts/sops/setup.sh): Drop sudo, drop `yi` age key generation, enforce root:root 0700 perms.
- \[`users/scripts/sops/sync-secrets.sh`\](file:///home/yi/the.files/nixos/users/scripts/sops/sync-secrets.sh): Set root:root 0700/0600 perms for secrets sync.
- \[`modules/nix-settings.nix`\](file:///home/yi/the.files/nixos/modules/nix-settings.nix): Remove `yi` from `nix.settings.trusted-users`.
- \[`modules/nix-access-tokens.nix`\](file:///home/yi/the.files/nixos/modules/nix-access-tokens.nix): Change group from `wheel` to `yi`.
- \[`modules/services/ssh/default.nix`\](file:///home/yi/the.files/nixos/modules/services/ssh/default.nix): Option `yi.ssh.permitRootKeyLogin` and server `PermitRootLogin = "prohibit-password"`.
- \[`modules/services/ssh/dynamic.nix`\](file:///home/yi/the.files/nixos/modules/services/ssh/dynamic.nix): Client `Match User root` host-key identity configuration.
- \[`modules/services/tailscale.nix`\](file:///home/yi/the.files/nixos/modules/services/tailscale.nix): Cleanup `tailscale-up` wrapper.
- \[`hosts/yifuwuqi/configuration.nix`\](file:///home/yi/the.files/nixos/hosts/yifuwuqi/configuration.nix): Remove redundant `trusted-users = ["@wheel"]`; enable `yi.ssh.permitRootKeyLogin = true`.
- \[`hosts/yixiaoqing/configuration.nix`\](file:///home/yi/the.files/nixos/hosts/yixiaoqing/configuration.nix): Remove redundant `trusted-users = ["@wheel"]` and sudo PAM config.
- \[`hosts/yitaishi/configuration.nix`\](file:///home/yi/the.files/nixos/hosts/yitaishi/configuration.nix): Enable `yi.tailscale.ssh = true`.
- \[`hosts/yirukou/configuration.nix`\](file:///home/yi/the.files/nixos/hosts/yirukou/configuration.nix): Enable `yi.ssh.permitRootKeyLogin = true`.
- \[`users/assets/dotfiles/zsh/aliases.zsh`\](file:///home/yi/the.files/nixos/users/assets/dotfiles/zsh/aliases.zsh), \[`functions.zsh`\](file:///home/yi/the.files/nixos/users/assets/dotfiles/zsh/functions.zsh), \[`bindings.zsh`\](file:///home/yi/the.files/nixos/users/assets/dotfiles/zsh/bindings.zsh): Dead sudo tooling cleanup.
- \[`users/scripts/nix-sanity.sh`\](file:///home/yi/the.files/nixos/users/scripts/nix-sanity.sh), \[`users/scripts/nix-fix-uids.sh`\](file:///home/yi/the.files/nixos/users/scripts/nix-fix-uids.sh), \[`users/scripts/wipe-attic-cache.sh`\](file:///home/yi/the.files/nixos/users/scripts/wipe-attic-cache.sh): Root-only and `runuser` adjustments.
- \[`docs/src/services/secrets.md`\](file:///home/yi/the.files/nixos/docs/src/services/secrets.md): Update secrets documentation for root-only SOPS.

______________________________________________________________________

## Open Questions

- None — decisions locked. Deploy solution (`yifuwuqi` → clients) is a separate future plan.
