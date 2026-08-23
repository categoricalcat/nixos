# AI SSH (ai-ssh) Read-Only Access

`ai-ssh` is the only sanctioned remote-access lane for AI agents. Raw `ssh`,
`scp`, `sshfs`, `mosh`, and `rsync` are denied to the opencode agent
(`users/programs/opencode.nix`); every remote read must go through
`ai-ssh <host> <command>`, which is a read-only gate **enforced on the server**.

## Usage

```bash
ai-ssh <host> <command...>
```

The wrapper (`users/scripts/ai-ssh.sh`) connects as the read-only `ai` user
using `~/.ssh/id_ai_ed25519`, encodes the command as one base64 token per
argument (no eval, spaces/quotes survive verbatim), and the server-side gate
reconstructs and dispatches it. Only the whitelisted commands below run;
anything else is rejected.

Bare hostnames resolve via the generated ssh config
(`modules/services/ssh/dynamic.nix`):

- `yifuwuqi`, `yirukou` — LAN address (`10.42.0.2`, `10.42.0.1`)
- `yitaishi`, `yixiaoqing` — Tailscale address (VPN only; they expose ssh
  nowhere else)

## Gate whitelist

The gate is `modules/services/ssh/scripts/ai-gate.sh`, wired via
`Match User ai` in `modules/services/ssh/default.nix`. It allows:

| Command | Allowed forms |
| --- | --- |
| `hostname` | standalone execution |
| `ip` | read-only subcommands: `route`, `addr`, `link`, `neigh`, `rule`, `mroute` with `show`/`list` |
| `networkctl` | `status`, `list`, `lldp`, `label`, `dhcp-lease` |
| `ping` | standard ICMP ping reachability probes |
| `systemctl` | `status`, `is-active`, `is-failed`, `is-enabled`, `show`, `list-units`, `list-timers`, `list-sockets` |
| `journalctl` | read-only flags, `--no-pager` forced; `-f`/`--follow` (any cluster) denied |
| `cat`, `ls`, `readlink` | absolute paths under `/etc`, `/proc`, `/var/log`, `/nix/var/nix/profiles`, `/nix/store`, `/run/current-system`, `/run` (excluding protected secret/key paths) |

Everything else — shell escapes, `id`, `systemctl reboot`, writes, arbitrary
binaries — is denied. Options like `-o ProxyCommand=…` as the host argument are
refused by the wrapper before ssh runs.

The `ai` user is a locked system account (`users/users.nix`): no shell, no TTY,
no forwarding, `AuthenticationMethods publickey`, `ForceCommand` the gate.
Host keys and the mesh-key/sops material under `/persist/keys` are outside the
path allowlist and additionally unreadable to the `ai` user.

## Provisioning a new host

1. On the new mesh host run `./users/scripts/setup-sops.sh <host>`, which
   generates `~yi/.ssh/id_ai_ed25519` and prints its public half.
2. Paste that `sshPublicKey` into `secrets/keys.nix` under
   `users.ai.meshKeys.<host>` (replacing the `null` placeholder).
3. Rebuild the host — every mesh host authorizes all non-null `ai` keys, so
   the new key works from every host at once.

## Threat model

- **Agent compromise** (opencode session taken over): can only run the gate's
  reads — read-only system state, journals, and allowlisted paths. Cannot
  write, escalate, or touch `/persist/keys` or user SSH material.
- **`ai` key theft**: same as agent compromise — the key is server-gated, so
  there is nothing beyond the whitelist to run.
- **Host-key pinning**: mesh host keys are pinned in `/etc/ssh/ssh_known_hosts`
  (`modules/services/ssh/known-hosts.nix`), generated from `secrets/keys.nix`.
  `ssh.fufu.land` stays `accept-new` as the out-of-band backup path.
