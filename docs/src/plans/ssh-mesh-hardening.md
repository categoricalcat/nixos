# SSH Mesh Hardening & AI Access Plan

## Objective

1. **Stop AI agents (opencode running as `yi`) from using raw SSH**; give them a
   sanctioned read-only lane instead.
2. **Harden the mesh**: pin host keys, disable password auth outside the LAN,
   remove dead/stray key material.

Constraints (from review):

- Keep `GatewayPorts yes` (reverse tunnels are used).
- Do **not** touch yifuwuqi's Google Authenticator TOTP (PAM
  `pam_google_authenticator`, keyboard-interactive — unaffected by
  `PasswordAuthentication`).
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
  (`setup-sops.sh` → `/persist/keys/sops/secrets.yaml`), encrypted to all 8
  recipients (4 host + 4 yi mesh keys) via a single `.sops.yaml` creation rule
  (regenerated from `secrets/generate-sops-yaml.nix`). Age identity is derived
  from the SSH host key (`sops.age.sshKeyPaths`). Consequence: any single
  host/yi key decrypts the whole blob. Accepted for the 4-machine mutual-trust
  mesh; per-host isolation is a possible future change, not part of this plan.
- **AI**: opencode runs as `yi` (`modules/services/opencode.nix` systemd unit,
  `User = yi`; interactive sessions as `yi`). `users/programs/opencode.nix` sets
  no Bash permission rules, so `ssh` falls back to `ask` and gets approved.
- **Mesh topology**: 4 wired hosts (yifuwuqi, yitaishi, yirukou, yixiaoqing)
  import `modules/services/openssh.nix`. A 5th host, `yichuang` (WSL), exists in
  the flake and imports `users/users.nix` but NOT the openssh module — mesh
  changes are scoped to the 4 wired hosts; `users.nix` changes apply to it too
  (harmless, its `users.ai` authorized_keys map is simply empty until wired).
- **`ssh.fufu.land`** (cloudflared): token-based tunnel running on yifuwuqi
  (`modules/services/cloudflared.nix`), config lives in the Cloudflare
  dashboard. It is the out-of-band backup path for when the mesh/VPN is down.
  Its backend host key is not visible from the repo and may be repointed during
  maintenance → keep `accept-new` for this host only.
- **TOTP**: yifuwuqi's sshd PAM stack runs `pam_google_authenticator`
  (`no_increment_hotp`) via keyboard-interactive. `PasswordAuthentication` is
  currently `yes` globally (default). No `Match` blocks besides `nix-builder`.

## Decisions (locked)

- `ssh.fufu.land`: keep `StrictHostKeyChecking accept-new` (per-host override).
  Backend may shift during maintenance; pinning would break the fallback.
- `ai` user joins `systemd-journal`: read-only by design; `yi` already belongs
  to it; the gate is `ForceCommand`-enforced so a hostile key can only run
  whitelisted reads (and `cat /var/log/*` is already in the gate allowlist).
- `ai-ssh` is a **system package** (`environment.systemPackages`): the opencode
  systemd unit (`User = yi`) does not see home-manager's `~/.nix-profile/bin`.
- The ssh skill lives at `~/.agents/skills/ssh/SKILL.md` — the repo `.agents/`
  is gitignored and opencode loads skills from `~/.agents/skills/`.

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

Note: the repo rule `~/.agents/rules/antigravity-rtk-rules.md` prefixes shell
commands with `rtk`, hence `Bash(rtk ssh*)` must also be denied.

`nixos-rebuild` stays `ask` (local builds work, remote deploys need yi).

### 1.2 Skill (not a rule)

New `~/.agents/skills/ssh/SKILL.md` following the nixos skill pattern
(`~/.agents/skills/nixos/SKILL.md`), frontmatter `name: ssh` + `description` +
`alwaysApply: true`. Skill content (also mirrored in the `etiquette` skill's
"Remote access" section, `modules/services/ai/etiquette-skill.md`):

- Remote reads only via `ai-ssh <host> <command>`.
- Never raw `ssh`, `scp`, `sshfs`, `mosh`, `rsync`.
- Never `nixos-rebuild --target-host` / `--build-host` (ask the user instead).
- `ai-ssh` is not deployed yet — until it is, ask the user before any remote
  access.

### 1.3 `ai-ssh` wrapper

New `users/programs/ssh/ai-ssh.sh` (sibling of `yssh.sh`, which is removed in
Phase 2):

```bash
#!/usr/bin/env bash
set -euo pipefail
exec ssh -l ai -i ~/.ssh/id_ai_ed25519 \
  -o IdentitiesOnly=yes \
  -o BatchMode=yes \
  -o ConnectTimeout=5 \
  -o StrictHostKeyChecking=yes \
  "$@"
```

Packaged as `pkgs.writeShellScriptBin "ai-ssh"` (read from `./ai-ssh.sh`, same
pattern as `ysshApp`) and installed in **both** `home.packages` (interactive
shells) and `environment.systemPackages` (opencode systemd unit + all shells).

Phase 1 is config-only and safe; `ai-ssh` fails gracefully until Phase 3 lands
the private key at `~yi/.ssh/id_ai_ed25519`.

## Phase 2 — mesh hardening

### 2.1 Pin host keys (drop TOFU)

- `users/assets/dotfiles/ssh/config:22` — `StrictHostKeyChecking accept-new`
  → `yes`. This asset is shared by `users/programs/ssh/default.nix`
  (home-manager) and `modules/services/openssh.nix` (system ssh_config), so one
  edit covers every mesh client.
- Add per-host override under the `Host ssh.fufu.land` block:
  `StrictHostKeyChecking accept-new` (backup path; see Decisions).
- `modules/distributed-builds.nix:58` — `StrictHostKeyChecking accept-new`
  → `yes` in the builder Host blocks (belt-and-braces; bare-name entries cover
  nix-builder connections).
- **New `modules/ssh-known-hosts.nix`** — generates `programs.ssh.knownHosts`
  from `secrets/keys.nix` (`keys.hosts.*.sshPublicKey`) × `modules/addresses.nix`:

  ```nix
  programs.ssh.knownHosts = lib.genAttrs (lib.attrNames keys.hosts) (name: {
    hostNames = [ name ] ++
      (map (a: "${name}.${a.suffix}") allAddresses.aliases) ++
      # all reachable IPs for defense-in-depth
      <lan/ts/nb ipv4 hosts where present>;
    publicKey = keys.hosts.${name}.sshPublicKey;
  });
  ```

  Covers bare, `.ts`, `.nb`, `.lan`, `.local` aliases plus IPs. NixOS writes
  `/etc/ssh/ssh_known_hosts` and adds `GlobalKnownHostsFile` to the system
  ssh_config (verified in nixpkgs `programs/ssh.nix`) — read by root/nix-builder
  and yi alike. Imported by `modules/services/openssh.nix` (all 4 mesh hosts).
- `ssh.fufu.land` (cloudflared) keeps `accept-new` — no pin (see Decisions).

### 2.2 Password auth: LAN only

`modules/services/openssh.nix`:

- `settings.PasswordAuthentication = false;` (global)
- Prepend to `extraConfig`, **before** the existing `Match User nix-builder`
  block:

  ```
  Match Address 10.42.0.0/24
    PasswordAuthentication yes
  ```

`Match Address` matches the **client source address** — LAN clients
(10.42.0.0/24) get password auth, ts/nb/cloudflared clients do not.
`Match User nix-builder` after it explicitly sets `PasswordAuthentication no`
and `AuthenticationMethods publickey`, so builders stay locked.
`KbdInteractiveAuthentication` untouched (PAM TOTP on yifuwuqi).

### 2.3 Keep `none` user

No change — sandbox identity. (Left its password hash as-is per review.)

### 2.4 Remove stray `~/.ssh/nix-builder-key`

Unused third key (neither mesh nor host key; absent from `keys.nix`; referenced
nowhere in the repo — only in this plan doc). Before deleting, check its mtime
and `auth.log` for usage on each mesh host. Then delete `.pub` + private half
from `~yi/.ssh/` on all 4 hosts.

### 2.5 Remove `yssh`

- Delete `users/programs/ssh/yssh.sh`.
- Remove `ysshApp`/`ysshWrappers` (`ssh-<host>` wrappers) and the
  `home.packages = ysshWrappers` line from `users/programs/ssh/default.nix`.
- Keep `dynamicSshConfig` — plain `ssh <host>.<suffix>` remains the connect path.
- `yssh` is referenced nowhere else in the repo (only this plan doc).

## Phase 3 — read-only `ai` account (server-enforced)

### 3.1 Keys

`secrets/keys.nix` — add `users.ai.meshKeys` mirroring `users.yi.meshKeys`
(4 per-host keys, each with `sshPublicKey`; ageRecipient not needed):

```nix
users = {
  yi = ...;  # unchanged
  ai = {
    sshAuthorizedKeys = builtins.filter (x: x != null) (
      map (k: k.sshPublicKey) (builtins.attrValues meshKeys)
    );
    meshKeys = {
      yifuwuqi = { sshPublicKey = "<ai pub key>"; };
      yitaishi = { sshPublicKey = "<ai pub key>"; };
      yirukou  = { sshPublicKey = "<ai pub key>"; };
      yixiaoqing = { sshPublicKey = "<ai pub key>"; };
    };
  };
};
```

**Not** added to `sopsAgeRecipients` — the ai gate needs no secrets. Each host
authorizes all 4 ai keys (same all-to-all pattern as `yi`).

### 3.2 User

`users/users.nix`:

```nix
ai = {
  isSystemUser = true;
  group = "nogroup";
  shell = "/bin/sh";
  openssh.authorizedKeys.keys = keys.users.ai.sshAuthorizedKeys;
  supplementaryGroups = [ "systemd-journal" ];  # full read-only journal
};
```

### 3.3 sshd gate

`modules/services/openssh.nix`:

- `AllowUsers` → add `"ai"`.
- New `Match User ai` block (server-enforced, so a hostile key can only run the
  gate):

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

- `ai-gate`: Nix `writeShellScript`, injection-safe (dispatch on first arg,
  args passed verbatim via `"$@"`, no eval), whitelisted binaries from
  `/run/current-system/sw/bin`:
  - `systemctl`: status, is-active, is-failed, is-enabled, show, list-units,
    list-timers, list-sockets
  - `journalctl`: read-only flags, no `-f`
  - `cat`, `ls`, `readlink`: paths restricted to a per-host allowlist
    (default `/etc`, `/proc`, `/var/log`, `/nix/var/nix/profiles`)
  - everything else rejected

### 3.4 Provisioning

`users/scripts/setup-sops.sh` — add an ai-key generation step mirroring the
mesh-key block: `ssh-keygen -t ed25519 -N "" -f ~yi/.ssh/id_ai_ed25519 -C
"ai@$HOSTNAME"`, chown/chmod 0600, and print the pub half with instructions to
paste into `keys.nix` (same pattern as the existing "Add to secrets/keys.nix"
output). Run on all 4 mesh hosts, update `keys.nix`, rebuild all together.

The local private half lives at `~yi/.ssh/id_ai_ed25519` (opencode runs as yi),
used only by `ai-ssh` — which opencode already allows (Phase 1).

## Rollout order

1. Phase 1 — config-only, safe. Rebuild any host.
2. Phase 2 — rebuild all mesh hosts together (known_hosts must be in place
   before `StrictHostKeyChecking yes` bites). Delete stray key + yssh.
3. Phase 3 — generate ai keys (setup-sops.sh), update `keys.nix`, rebuild all
   mesh hosts together.
4. Phase 4 — docs.

## Phase 4 — docs

- `docs/src/services/nix-build-cache.md` — "Builder SSH Keys" section: note
  host keys are now pinned via `/etc/ssh/ssh_known_hosts`
  (`modules/ssh-known-hosts.nix` regenerates from `keys.nix`/`addresses.nix`).
- `docs/src/services/secrets.md` — all-to-all recipients note (partially there);
  document `ai` keys as read-only-gate-only, not sops recipients.
- New `docs/src/services/ai-ssh.md` — usage (`ai-ssh <host> <command>`), gate
  whitelist, threat model.

## Open questions / follow-ups

- `ssh.fufu.land` backing host: unpinned by design (backup path). Revisit only
  if the tunnel becomes a permanent primary route.
- Additional `ai` gate paths beyond the defaults?
- Move the opencode `serve` daemon off `yi`? Deferred; the sshd-side gate is the
  enforcement boundary regardless of process user.
- Per-host sops isolation: possible future change, not part of this plan.
