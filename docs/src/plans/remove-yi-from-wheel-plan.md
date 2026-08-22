# Unprivileged Daily User (`yi`) & Explicit Root Administration Plan

## Objective

Configure `yi` as a **completely unprivileged daily user account** with no ambient root powers, while establishing a secure, explicit mechanism for the human operator to perform administrative work as `root`.

## Current State

- `users/users.nix`: `yi` belongs to the `wheel` group (`users.users.yi.extraGroups = [ "wheel" ... ]`).
- Ambient Superuser Power: Because `yi` is in `wheel`, any process running as `yi` (desktop apps, web browsers, dev tools, AI tools, shell scripts) can execute commands as root using `yi`'s password or through active `sudo` credential caches.
- Root Account: Currently has no dedicated SOPS password file; `PermitRootLogin no` is enabled on SSH.

## Architecture: Truly Unprivileged Daily User

```
+-----------------------------------------------------------------------------+
|                            Daily User Session (`yi`)                         |
|                                                                             |
|   [Web Browser]    [VS Code / Zed]    [AI Agents]    [Gaming]    [Shell]     |
|         |                 |                |            |           |       |
|         +-----------------+----------------+------------+-----------+       |
|                                   |                                         |
|                                   v                                         |
|                 No 'wheel' group, No sudoers privileges                     |
|                 Sudo attempts by 'yi' -> DENIED (Exit 1)                    |
+-----------------------------------------------------------------------------+
                                    |
              (Explicit human authentication required for admin)
                                    |
                                    v
+-----------------------------------------------------------------------------+
|                          Explicit Root Escalation                           |
|                                                                             |
|   Option A: `su -` (Requires Root's distinct password)                      |
|   Option B: `sudo` configured with `rootpw` + `timestamp_timeout = 0`        |
|   Option C: Local Virtual Console / TTY login as `root`                     |
+-----------------------------------------------------------------------------+
                                    |
                                    v
                       [ ROOT MAINTENANCE TASKS ]
                      (nixos-rebuild switch, services)
```

## Decisions

1. **Remove `wheel` from `yi`**:
   - In `users/users.nix`, remove `"wheel"` from `users.users.yi.extraGroups`.
   - `yi` will have zero ambient sudo privileges.
2. **Explicit Root Password via SOPS**:
   - Define `users.users.root.hashedPasswordFile = config.sops.secrets."passwords/root".path;` (or let the operator set it via `passwd root`).
   - Add `"passwords/root"` secret to SOPS secrets map.
3. **Escalation Mechanism for Maintenance**:
   - When administrative tasks are needed, the human runs `su -` and enters the **root password** (a dedicated, strong passphrase completely different from `yi`'s password).
   - Alternatively / additionally: if `sudo` is kept for convenience, configure `Defaults rootpw, timestamp_timeout = 0` so that `sudo` strictly prompts for **root's password** with zero caching, rather than `yi`'s password.
4. **SSH Security**:
   - `PermitRootLogin no` remains strictly enforced. Remote SSH login as `root` is forbidden.
   - Remote maintenance is done by SSHing as `yi` and then explicitly executing `su -` with root's password.
5. **Nix Daemon & Secrets Adjustment**:
   - Keep `yi` in `nix.settings.trusted-users` in `modules/nix-settings.nix` so `yi` can still build flakes and query stores without root.
   - In `modules/nix-access-tokens.nix`, update `group = "wheel"` to `group = "yi"`.
   - In `users/scripts/setup-sops.sh`, update `/persist/keys/sops` ownership from `root:wheel` to `root:root` (or `root:yi`).

## Phases

### Phase 1: Secrets & Root Account Configuration
- [ ] Add `passwords/root` to SOPS secrets and configure `users.users.root.hashedPasswordFile`.
- [ ] Ensure root has a dedicated, secure password distinct from `yi`.

### Phase 2: De-Privileging `yi`
- [ ] Remove `"wheel"` from `users.users.yi.extraGroups` in `users/users.nix`.
- [ ] Update `modules/nix-access-tokens.nix` group ownership.
- [ ] Remove `@wheel` references from `hosts/yifuwuqi/configuration.nix` and `hosts/yixiaoqing/configuration.nix`.

### Phase 3: Sudo & Escalation Policy Configuration
- [ ] Set `security.sudo.extraConfig`:
  ```nix
  Defaults rootpw
  Defaults timestamp_timeout = 0
  ```
  *(Allows `sudo` to be used by asking for root's password with zero session caching, or disable sudo completely in favor of `su -`)*.

### Phase 4: Validation
- [ ] Run `nix eval` on all host configurations.
- [ ] Test on `yifuwuqi`: verify `yi` cannot run `sudo` with `yi`'s password, verify `su -` succeeds with root's password, verify `nixos-rebuild` can be executed under root.

## Rollout Order

1. **User sets root password in SOPS**:
   - Add `passwords/root` hash to `secrets/secrets.yaml`.
2. **Apply configuration**:
   - The user runs `sudo nixos-rebuild test --flake .#yifuwuqi`.
3. **Verify unprivileged behavior**:
   - `sudo -k` as `yi` -> fails or requires root's password.
   - `su -` -> succeeds with root's password.
4. **Switch permanently**:
   - Run `nixos-rebuild switch --flake .#yifuwuqi` inside the `su -` root shell.

## Open Questions

1. **Escalation Tool Preference**:
   Do you prefer using `su -` (pure Unix standard switch to root) or `sudo` configured to require root's password (`Defaults rootpw`) with zero caching?
