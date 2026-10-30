# Auto-Maintenance

Forgejo Actions prepares one pull request from `bot/auto-maintenance` to
`develop` that updates `flake.lock`. Each run rebuilds the bot branch from
current `develop`, runs `nix flake update`, and verifies the result with
`nix flake check --no-build` and `nix-fast-build --flake .#hydraJobs`. A green
update is committed as is; only a failed verification summons `agy`, inside an
unprivileged sandbox, to repair it.

The workflow runs manually or at 05:30 and 17:30 UTC (02:30 and 14:30 in
`America/Sao_Paulo`).

## Security & Isolation

`forgejo-runner-yifuwuqi.service` runs as `nix-builder:nogroup`, which owns the
gang deploy key (`/var/lib/nix-builder/.ssh/id_ed25519`), pushes to Attic, and
is a `nix-daemon` `trusted-user`. `ci/auto-maintenance.sh` keeps every untrusted
step away from that identity:

1. **Unauthenticated checkout**: `actions/checkout` is pinned to a commit SHA
   with `persist-credentials: false` and no write token. The script's fetch is
   anonymous (`yi/nixos` is public).
1. **Locked agent binary**: `antigravity-nix` is a locked flake input. The
   script resolves `agy` from the reviewed `develop` lockfile, and the update
   only touches the sandbox's copy, so an unreviewed `antigravity-nix` commit
   never runs.
1. **Real uid switch (`drop-to-none`)**: nix-daemon decides trust from the
   caller's real uid, which a bwrap user namespace leaves as `nix-builder`.
   `modules/services/forgejo-runner.nix` therefore installs util-linux `setpriv`
   as a setuid/setgid `none:none` wrapper at `/run/wrappers/bin/drop-to-none`,
   executable only by group `none` (`nix-builder` is a member). Called as
   `drop-to-none --reuid=none --regid=none --keep-groups --no-new-privs`, it
   makes sandboxed processes the untrusted `none` user to nix-daemon, unable to
   read `nix-builder` files. The supplementary group `nogroup` cannot be dropped
   without root; the mount namespace below hides everything it could read.
1. **Bubblewrap sandbox**: every untrusted step (`nix flake update`,
   verification, `agy`) runs in
   `bwrap --unshare-all --share-net --die-with-parent --new-session --clearenv`
   with read-only `/nix`, `/etc`, `/run/current-system`, `/bin`, `/usr/bin` and
   `/lib64`, tmpfs `/tmp` and `/home/none`, and a read-write `/work`. `/work` is
   a `git archive` copy of `develop` owned by `none`; the outer checkout, its
   `.git`, and the running script are never mounted. The PID namespace ensures
   no process outlives a sandbox call.
1. **Network**: every sandbox step needs the network, verification included:
   evaluating niri's cargo vendoring runs `fetchGit` (Smithay) at evaluation
   time, and the sandbox's fresh home has no fetcher cache. The
   `sandbox-egress` nftables table in `modules/services/forgejo-runner.nix`
   therefore rejects uid `none`'s traffic to loopback, private LAN ranges,
   link-local, ULA and the tailnet (`100.64.0.0/10`), allowing only DNS to the
   local resolver and the public internet. Exfiltration to the internet stays
   possible, so treat the agy OAuth token as exposed to the agent.
1. **Token injection**: `bwrap --file` writes the agy OAuth token into the
   agent's tmpfs home for the repair call only; it never touches the host
   filesystem. The Forgejo PAT stays in the outer script's memory: curl reads it
   from a process-substitution header file and `git push` from `GIT_CONFIG_*`
   environment variables, never from argv or a file on disk.
1. **Protected paths**: Forgejo CI on the pull request, and the GitHub push
   mirror's self-hosted runner, execute `.forgejo/`, `.gitea/`, `.github/`,
   `ci/` and `nix/scripts/` as `nix-builder`, outside the Nix sandbox. The
   script refuses to commit any change under those paths.

## Branch & PR Lifecycle

1. Fetch `origin` and reset `bot/auto-maintenance` to `origin/develop`.
1. Run `nix flake update` in the sandbox. Exit `0` if `flake.lock` is unchanged.
1. Verify in the sandbox. On failure, summon `agy` with the last 200 log lines.
1. Stage the copy with `git --work-tree`, apply the protected-path guard, and
   commit `chore(flake): update flake.lock`, or
   `chore(flake): update flake.lock and repair build` when more than
   `flake.lock` changed.
1. Skip the push when `origin/bot/auto-maintenance` already has the same tree;
   otherwise `push --force-with-lease`.
1. Ensure an open pull request from `bot/auto-maintenance` to `develop` exists,
   creating one if needed.

Each run replaces the branch with one fresh commit on top of current `develop`,
so the open pull request always shows `develop` plus the latest inputs.

## Forgejo Setup

1. Ensure the **Pull Requests** repository unit is enabled on `yi/nixos`
   (**Settings → Units → Enable Pull Requests**).
1. Create a non-admin `auto-maintenance` user, add it to `yi/nixos` as a Write
   collaborator, and create a minimum-scope `write:repository` token. Keep
   `develop` protected so only `yi` can push or merge, with required approval
   and CI.
1. Configure these repository Actions secrets:

| Secret                   | Value                                                                          |
| ------------------------ | ------------------------------------------------------------------------------ |
| `AGY_OAUTH_TOKEN`        | Complete contents of `antigravity-oauth-token` from a temporary agy login home |
| `AUTO_MAINTENANCE_TOKEN` | PAT for the `auto-maintenance` Forgejo user                                    |

Use the dedicated PAT for publishing. Forgejo deliberately suppresses workflow
events caused by its automatic Actions token, whereas bot-PAT pushes trigger
the pull request's normal CI.

## Operation

Run **Actions → Auto Maintenance → Run workflow** for an immediate run.
Scheduled and manual runs share one non-cancelling concurrency group.

Review the commit and CI in the pull request and merge when ready; the bot never
merges. Closing the pull request does not stop later runs: the next run opens a
fresh one unless `develop`'s `flake.lock` is already current. Disable the
schedule to pause updates.

After deploying a change to `modules/services/forgejo-runner.nix`, restart
`forgejo-runner-yifuwuqi.service` while it is idle (the unit has
`restartIfChanged = false`) so the runner picks up its `none` group membership.
