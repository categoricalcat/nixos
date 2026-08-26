# Unprivileged Daily User (`yi`) & Client-Root→Server-Root Admin Lane

## Objective

Configure `yi` as a **completely unprivileged daily user account** with no
ambient root powers, while establishing a secure, explicit mechanism for the
human operator to perform administrative work as `root`.

Root must be reachable only through:

1. **Client-root → server-root SSH keys** (the sanctioned remote admin lane),
1. **Tailscale SSH** (lockout rescue, operator identity only), and
1. **Physical console** (break-glass).

## Threat Model

The mesh = `yi`'s N×N ssh keys + the read-only `ai` lane. Mesh compromise
yields `yi` on every host. Therefore `yi` must have **zero root**: no wheel, no
sudo, and crucially **not** in `nix.settings.trusted-users` (a trusted Nix user
is root-equivalent — they can inject trusted substituters and drive the root
daemon into executing arbitrary paths).

## Decisions

### 1. `yi` fully unprivileged

- `users/users.nix`: remove `"wheel"` from `users.users.yi.extraGroups`.
- `hosts/yifuwuqi/configuration.nix` + `hosts/yixiaoqing/configuration.nix`:
  `nix.settings.trusted-users = ["@wheel"]` → `["yi"]`.
- `modules/nix-settings.nix`: **remove `"yi"` from `trusted-users`** (keep
  `["root" "nix-builder"]`). `yi` stays in `allowed-users`, which is sufficient
  to build flakes and query the store as a sandboxed user. All binary caches
  are configured globally, so `yi` loses nothing functional.
- `modules/nix-access-tokens.nix`: `group = "wheel"` → `"yi"`.
- `users/scripts/setup-sops.sh`: `/persist/keys/sops` ownership `root:wheel`
  → `root:root` (and sync `docs/src/services/secrets.md`).

**Known local exception** (documented, not blocking): `hosts/yitaishi/gaming.nix`
grants `yi` NOPASSWD sudo for `systemctl start/stop` on `coolercontrold.service`
and `lactd.service` only. It is scoped to that one client and cannot touch
servers.

### 2. Root password (Option A) via SOPS

- Add `passwords/root` to the SOPS secrets map.
- `users.users.root.hashedPasswordFile = config.sops.secrets."passwords/root".path`
  on **all hosts** (`users/users.nix`).
  - Clients: enables local `su -`.
  - Servers: pure physical-console break-glass. Never exposed on the network
    because sshd keeps `PasswordAuthentication off` and `PermitRootLogin`
    key-only.

### 3. Client-root → server-root SSH (reusing host keys)

- **No new keys needed**: Root on clients (`yixiaoqing`, `yitaishi`) authenticates
  using each client's existing SSH host key (`/persist/keys/ssh/ssh_host_ed25519_key`),
  mirroring the `nix-builder` distributed build mesh pattern.
- `secrets/keys.nix`: unchanged — `hosts.<client>.sshPublicKey` is already registered.
- `users/scripts/setup-sops.sh`: no key generation changes needed.
- Servers (`yifuwuqi`, `yirukou`):
  `users.users.root.openssh.authorizedKeys.keys = [ keys.hosts.yixiaoqing.sshPublicKey keys.hosts.yitaishi.sshPublicKey ];`
- `modules/services/ssh/default.nix`:
  - Add option `yi.ssh.permitRootKeyLogin` (bool).
  - Servers: `PermitRootLogin = "prohibit-password"` **and add `"root"` to
    `AllowUsers`** (root is not currently in `AllowUsers`, so `PermitRootLogin`
    alone would not let root in).
  - Clients: `PermitRootLogin = "no"` (unchanged).
  - Add OpenSSH client match block to `programs.ssh.extraConfig` so `su -` → `ssh root@<server>` automatically uses the host key:
    ```ssh
    Match User root
        IdentityFile ${keys.paths.sshHostKey}
    ```

### 4. Tailscale SSH = lockout rescue (critical)

- Already enabled on yifuwuqi and yirukou (`yi.tailscale.ssh = true`).
  **Verify `tailscale ssh root@host` from a trusted device works before any
  sshd change.**
- Clients:
  - yixiaoqing: `yi.tailscale.ssh = true`.
  - yitaishi: enable the `../../modules/services/tailscale.nix` import
    (currently commented out) and set `yi.tailscale.ssh = true`.
- Restrict the Tailscale ACL (admin console) to the operator's tailnet
  user/device only — otherwise any mesh host's identity could
  `tailscale ssh root@…`.

### 5. Unchanged

- `yi` stays in `nix.settings.allowed-users` (flake builds without root).
- `ai` read-only user and gate unchanged.
- `yi` mesh keys stay for daily inter-host use.

## Workflows

| Task                         | How                                                                          |
| ---------------------------- | ---------------------------------------------------------------------------- |
| Admin a server from a client | client TTY → `su -` (root pw) → `ssh root@yifuwuqi` → `nixos-rebuild switch` |
| Admin a client locally       | client TTY → `su -` → `nixos-rebuild switch`                                 |
| Rescue (broken sshd/keys)    | `tailscale ssh root@host` from trusted device                                |
| Last resort                  | physical console → `su -` / root login                                       |

## Rollout Order (lockout-safe)

1. **Verify Tailscale SSH rescue on servers first** — `tailscale ssh root@yifuwuqi`,
   `tailscale ssh root@yirukou` — before touching sshd.
1. Add `passwords/root` to SOPS; apply; test `su -` on a client.
1. Configure client host keys in server root `authorizedKeys` + add `Match User root` client config; flip servers to `prohibit-password` + add root to `AllowUsers`.
1. Test client-root → server-root SSH (`su -` on client → `ssh root@server`). Confirm `yi` cannot reach root.
1. De-wheel `yi`; clean up `@wheel` refs, access-tokens group, setup-sops.sh.
1. Validate all hosts:
   - `yi` cannot `sudo` or act as a trusted Nix user.
   - client-root → server-root SSH works.
   - Tailscale SSH rescue works.
   - `nixos-rebuild switch` works under root.

## Files Touched

- `users/users.nix`
- `users/scripts/setup-sops.sh` (directory permission change only)
- `secrets/secrets.yaml` (+ sops)
- `modules/nix-settings.nix`
- `modules/nix-access-tokens.nix`
- `modules/services/ssh/default.nix`
- `hosts/yifuwuqi/configuration.nix`
- `hosts/yixiaoqing/configuration.nix`
- `hosts/yitaishi/configuration.nix` (+ tailscale import)
- `hosts/yirukou/configuration.nix`
- `docs/src/services/secrets.md`

## Open Questions

- None — decisions locked. Deploy solution (yifuwuqi → clients) is a separate
  future plan.
