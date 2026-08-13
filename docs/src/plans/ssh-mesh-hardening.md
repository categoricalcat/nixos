# SSH Mesh Hardening & AI Access Plan

## Objective

1. **Stop AI agents (opencode running as `yi`) from using raw SSH**; give them a
   sanctioned read-only lane instead.
2. **Harden the mesh**: pin host keys, disable password auth outside the LAN,
   remove dead/stray key material.

Constraints (from review):

- Keep `GatewayPorts yes` (reverse tunnels are used).
- Do **not** touch yifuwuqi's Google Authenticator TOTP.
- Keep the `none` user (bubblewrap sandbox identity, `nix/devshell.nix`).
- Keep host-key-as-age and host-key-as-builder (no new age/builder keys).

## Current state

- **Build mesh** (`modules/distributed-builds.nix`): hosts SSH to each other as
  `nix-builder`, authenticating with their own SSH **host** key
  (`/persist/keys/ssh/ssh_host_ed25519_key`). `nix-builder` is locked via
  `Match User nix-builder` (`ForceCommand nix-daemon --stdio`).
- **User mesh** (`secrets/keys.nix` → `users.yi.meshKeys`): every host's `yi`
  authorized_keys accepts all other hosts' `yi` keys. `yssh` races routes (ts/nb/lan).
- **Secrets**: one shared `secrets/secrets.yaml` synced to every host
  (`setup-sops.sh` → `/persist/keys/sops/secrets.yaml`), encrypted to **all 8
  recipients** (4 host + 4 yi mesh keys) via a single `.sops.yaml` creation rule.
  Age identity is derived from the SSH host key (`sops.age.sshKeyPaths`) — the
  standard sops-nix pattern. Consequence: any single host/yi key decrypts the
  whole blob. Accepted for the 4-machine mutual-trust mesh; per-host isolation is
  a possible future change, not part of this plan.
- **AI**: opencode runs as `yi` (`modules/services/opencode.nix` systemd unit,
  `User = yi`; interactive sessions as `yi`). `users/programs/opencode.nix` sets
  no Bash permission rules, so `ssh` falls back to `ask` and gets approved.

## Phase 1 — AI read-only lane, raw SSH denied

### 1.1 Deny raw SSH in opencode

`users/programs/opencode.nix` — extend `permission`:

```nix
permission = {
  # ...existing (webfetch, websearch, question, task, firecrawl_*)...
  "Bash(ssh*)" = "deny";
  "Bash(scp*)" = "deny";
  "Bash(sshfs*)" = "deny";
  "Bash(mosh*)" = "deny";
  "Bash(rtk ssh*)" = "deny";
  "Bash(rsync*)" = "deny";
  "Bash(ai-ssh*)" = "allow";
};
```

`nixos-rebuild` stays `ask` (local builds work, remote deploys need yi).

### 1.2 Skill (not a rule)

New `.agents/skills/ssh/SKILL.md` following the repo skill pattern
(`.agents/skills/nixos/SKILL.md`), frontmatter `name: ssh` + `description` +
`alwaysApply: true`:

- Remote reads only via `ai-ssh <host> <command>`.
- Never raw `ssh`, `scp`, `sshfs`, `mosh`, `rsync`.
- Never `nixos-rebuild --target-host` / `--build-host` (ask the user instead).

### 1.3 `ai-ssh` wrapper

Sibling of `users/programs/ssh/yssh.sh` (which is removed in Phase 2). Invokes
ssh with `-i ~/.ssh/id_ai_ed25519 -o IdentitiesOnly=yes -o
StrictHostKeyChecking=yes -o BatchMode=yes -o ConnectTimeout=5`, passing the
host + command through.

## Phase 2 — mesh hardening

### 2.1 Pin host keys (drop TOFU)

`StrictHostKeyChecking accept-new` → `yes`, with `programs.ssh.knownHosts`
generated from `secrets/keys.nix` (`keys.hosts.*.sshPublicKey`) covering all
aliases (bare, `.ts`, `.nb`, `.lan`, `.local`). Applies to
`modules/distributed-builds.nix`, `modules/ssh-dynamic.nix`, and
`users/programs/ssh/default.nix`. `ssh.fufu.land` (cloudflared) keeps
`accept-new` unless its backing host key is pinned.

### 2.2 Password auth: LAN only

Global `PasswordAuthentication no` in `services.openssh.settings`, then in
`extraConfig`:

```
Match Address 10.42.0.0/24
  PasswordAuthentication yes
```

`KbdInteractiveAuthentication` untouched (TOTP). VPN/cloudflared stay password-off.

### 2.3 Keep `none` user

No change — sandbox identity. (Left its password hash as-is per review.)

### 2.4 Remove stray `~/.ssh/nix-builder-key`

Unused third key (neither mesh nor host key; absent from `keys.nix`). Confirm no
external workflow uses it, then delete `.pub` + private half.

### 2.5 Remove `yssh`

Delete `users/programs/ssh/yssh.sh` and the `ysshApp`/`ysshWrappers`
(`ssh-<host>` wrappers) from `users/programs/ssh/default.nix`. Keep
`dynamicSshConfig` — plain `ssh <host>.suffix` remains the connect path.

## Phase 3 — read-only `ai` account (server-enforced)

- New `ai` user on all mesh hosts (`users/users.nix`): no password, no `wheel`,
  `shell = /bin/sh`, added to `AllowUsers`.
- Per-host `ai` keys in `secrets/keys.nix` (mirroring `meshKeys`); each host
  authorizes all others' `ai` keys.
- `modules/services/openssh.nix` — `Match User ai` block (server-enforced, so a
  hostile key can only run the gate):

```
Match User ai
  AuthenticationMethods publickey
  PasswordAuthentication no
  KbdInteractiveAuthentication no
  X11Forwarding no
  AllowTcpForwarding no
  AllowAgentForwarding no
  AllowStreamLocalForwarding no
  PermitTTY no
  ForceCommand <ai-gate>
```

- `ai-gate` script (Nix `writeShellScript`, injection-safe, no eval, whitelisted
  binaries from `/run/current-system/sw/bin`):
  - `systemctl`: status, is-active, is-failed, is-enabled, show, list-units,
    list-timers, list-sockets
  - `journalctl`: read-only flags, no `-f`
  - `cat`, `ls`, `readlink`: paths restricted to a per-host allowlist
    (default `/etc`, `/proc`, `/var/log`, `/nix/var/nix/profiles`)
  - everything else rejected
- Local private half installed at `~yi/.ssh/id_ai_ed25519` (opencode runs as
  yi), used only by `ai-ssh`. opencode already allows `ai-ssh` (Phase 1).

## Rollout order

1. Phase 1 — config-only, safe.
2. Phase 2 — rebuild all mesh hosts together.
3. Phase 3 — `ai` user + gate + `ai-ssh`.
4. Update docs: `nix-build-cache.md` (yssh removal), `secrets.md`
   (all-to-all note), new `ai-ssh` section.

## Open questions

- `ssh.fufu.land` backing host — pin its host key or keep `accept-new`?
- Additional `ai` gate paths beyond the defaults?
- Move the opencode `serve` daemon off `yi`? Deferred; the sshd-side gate is the
  enforcement boundary regardless of process user.
