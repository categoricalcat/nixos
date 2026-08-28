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
- NixOS sets `users.users.root.hashedPasswordFile = "/persist/keys/passwords/root"` on clients directly into `/etc/shadow`, operating 100% independently of SOPS.

### Why Tailscale SSH and Client-Root SSH Work Without Server `su -`

- **Tailscale SSH**: Handled directly by `tailscaled`, which verifies the operator's Tailscale cryptographic identity against Tailscale ACLs and launches a root session directly (does not require passwords, `su`, or `sshd`).
- **Client-Root SSH**: The operator runs `su -` on a client (using the static root password file on `/persist/keys/passwords/root`), then runs `ssh root@server`. OpenSSH daemon on the server authenticates the client's host public key against `users.users.root.openssh.authorizedKeys`.

## Decisions

### 1. Global Sudo Removal & Polkit for GameMode

- `modules/common.nix`: `security.sudo.enable = false;` globally across all hosts.
- `hosts/yitaishi/gaming.nix`: Replace `security.sudo.extraRules` with a declarative **Polkit rule** (`security.polkit.extraConfig`) allowing `yi` to start/stop `coolercontrold.service` and `lactd.service` without `sudo` or setuid wrappers. Update gamemode scripts to call `systemctl stop/start` directly.
- `modules/fido2.nix` & `hosts/yixiaoqing/configuration.nix`: Clean up obsolete `sudo` PAM options (`pam.services.sudo.u2fAuth`, `pam.services.sudo.fprintAuth`).
- `modules/services/tailscale.nix`: Update `tailscale-up` to invoke `tailscale up` directly (intended to run under root shell).

### 2. `yi` fully unprivileged & SOPS Restricted to Root

- `users/users.nix`: Remove `"wheel"` from `users.users.yi.extraGroups`.
- `secrets/keys.nix`: Remove all `users.yi.meshKeys.*.ageRecipient` from `sopsAgeRecipients`. Only `hosts.<host>.ageRecipient` remain.
- `secrets/sops.nix`: Remove `SOPS_AGE_SSH_PRIVATE_KEY_FILE` environment variable pointing to `yi`'s home.
- `hosts/yifuwuqi/configuration.nix` & `hosts/yixiaoqing/configuration.nix`: Remove redundant `nix.settings.trusted-users = ["@wheel"]` overrides.
- `modules/nix-settings.nix`: **Remove `"yi"` from `trusted-users`** (keep `["root" "nix-builder"]`). `yi` stays in `allowed-users`, which is sufficient to build flakes and query the store as a sandboxed user. All binary caches are configured globally, so `yi` loses nothing functional.
- `modules/nix-access-tokens.nix`: `group = "wheel"` → `"yi"` (read-only access to PAT fragment).
- `users/scripts/setup-sops.sh`:
  - `/persist/keys/sops` ownership `root:root` (`0700`).
  - Drop all `yi` age key generation.
  - Require running as root; replace `sudo -u yi` with `runuser -u yi --`.

### 3. Root Password via Static Hash File (Independent of SOPS)

- Root password is NOT stored in SOPS, preventing circular recovery lockouts if SOPS fails.
- Generate salted hash on clients: `mkpasswd -m yescrypt > /persist/keys/passwords/root` (`0600 root:root`).
- On clients (`yixiaoqing`, `yitaishi`):
  `users.users.root.hashedPasswordFile = "/persist/keys/passwords/root";`
- On servers (`yifuwuqi`, `yirukou`): No root password set (locked account, disabling `su -`).

### 4. Client-root → server-root SSH (reusing host keys)

- **No new keys needed**: Root on clients (`yixiaoqing`, `yitaishi`) authenticates using each client's existing SSH host key (`/persist/keys/ssh/ssh_host_ed25519_key`), mirroring the `nix-builder` distributed build mesh pattern.
- `secrets/keys.nix`: unchanged for host keys — `hosts.<client>.sshPublicKey` is already registered.
- Servers (`yifuwuqi`, `yirukou`):
  `users.users.root.openssh.authorizedKeys.keys = [ keys.hosts.yixiaoqing.sshPublicKey keys.hosts.yitaishi.sshPublicKey ];`
- `modules/services/ssh/default.nix`:
  - Add option `yi.ssh.permitRootKeyLogin` (bool).
  - Servers: `PermitRootLogin = "prohibit-password"` **and add `"root"` to `AllowUsers`** (root is not currently in `AllowUsers`, so `PermitRootLogin` alone would not let root in).
  - Clients: `PermitRootLogin = "no"` (unchanged).
  - Add OpenSSH client match block to `programs.ssh.extraConfig` so `su -` → `ssh root@<server>` automatically uses the host key:
    ```ssh
    Match User root
        IdentityFile ${keys.paths.sshHostKey}
    ```

### 5. Tailscale SSH = lockout rescue (critical)

- Already enabled on yifuwuqi and yirukou (`yi.tailscale.ssh = true`).
  **Verify `tailscale ssh root@host` from a trusted device works before any sshd change.**
- Clients:
  - yixiaoqing: `yi.tailscale.ssh = true`.
  - yitaishi: enable the `../../modules/services/tailscale.nix` import (currently commented out) and set `yi.tailscale.ssh = true`.
- Restrict the Tailscale ACL (admin console) to the operator's tailnet user/device only — otherwise any mesh host's identity could `tailscale ssh root@…`.

### 6. Unchanged

- `yi` stays in `nix.settings.allowed-users` (flake builds without root).
- `ai` read-only user and gate unchanged.
- `yi` mesh keys stay for daily inter-host use.

## Workflows

| Task                         | How                                                                          |
| ---------------------------- | ---------------------------------------------------------------------------- |
| Admin a server from a client | client TTY → `su -` (root pw) → `ssh root@yifuwuqi` → `nixos-rebuild switch` |
| Admin a client locally       | client TTY → `su -` → `nixos-rebuild switch`                                 |
| Rescue (broken sshd/keys)    | `tailscale ssh root@host` from trusted device                                |
| Edit SOPS secrets            | client TTY → `su -` → `sops secrets/secrets.yaml` (using host key)           |
| Server local isolation       | `yi` on server cannot `sudo`, `su -`, or decrypt SOPS                        |

## Rollout Order (lockout-safe)

1. **Verify Tailscale SSH rescue on servers first** — `tailscale ssh root@yifuwuqi`, `tailscale ssh root@yirukou` — before touching sshd.
1. Create `/persist/keys/passwords/root` on clients; test `su -` on a client.
1. Configure client host keys in server root `authorizedKeys` + add `Match User root` client config; flip servers to `prohibit-password` + add root to `AllowUsers`.
1. Test client-root → server-root SSH (`su -` on client → `ssh root@server`). Confirm `yi` cannot reach root.
1. Rekey SOPS without `yi` recipients (`sopsAgeRecipients` containing host keys only); set `/persist/keys/sops` to `0700 root:root`.
1. De-wheel `yi` and disable `sudo` globally (`security.sudo.enable = false;`); leave root password unconfigured on servers; apply Polkit rule on `yitaishi`; clean up `setup-sops.sh` and PAM configs.
1. Validate all hosts:
   - `sudo` is absent (`command not found`).
   - `yi` cannot read `/persist/keys/sops/secrets.yaml` or decrypt SOPS.
   - `yi` cannot act as a trusted Nix user.
   - `su -` works locally on clients, fails on servers (locked account).
   - client-root → server-root SSH works.
   - Tailscale SSH rescue works.
   - `nixos-rebuild switch` works under root.

## Files Touched

- `modules/common.nix` (disable sudo globally)
- `users/users.nix` (remove wheel, configure root hashedPasswordFile on clients)
- `secrets/keys.nix` (remove yi from sopsAgeRecipients)
- `secrets/sops.nix` (remove yi sops environment variables)
- `hosts/yitaishi/gaming.nix` (Polkit rule for coolercontrold / lactd)
- `modules/fido2.nix` (clean up sudo PAM)
- `users/scripts/setup-sops.sh` (drop sudo, drop yi age key generation, root:root 0700 perms)
- `modules/nix-settings.nix` (remove yi from trusted-users)
- `modules/nix-access-tokens.nix`
- `modules/services/ssh/default.nix`
- `modules/services/tailscale.nix` (tailscale-up cleanup)
- `hosts/yifuwuqi/configuration.nix`
- `hosts/yixiaoqing/configuration.nix`
- `hosts/yitaishi/configuration.nix` (+ tailscale import)
- `hosts/yirukou/configuration.nix`
- `docs/src/services/secrets.md`

## Open Questions

- None — decisions locked. Deploy solution (yifuwuqi → clients) is a separate future plan.
