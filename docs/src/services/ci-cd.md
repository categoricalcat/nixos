# CI/CD Pipeline & Actions Runners

This document details the automated continuous integration, parallel compilation, and binary cache publishing pipeline running on self-hosted Forgejo and GitHub Actions runners.

______________________________________________________________________

## 1. Pipeline Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                      Git Push / PR Event                    │
│             (to main, develop, or workflow_dispatch)        │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                Job: Build & Push (single job)               │
│  .#hydraJobs: checks, hosts, pkgs, shells                   │
│                                                             │
│  1. Run ci/build.sh                                         │
│     ├── Probe yitaishi on port 24212 (Tailscale / NetBird)  │
│     ├── If online: offload derivations via ssh-ng           │
│     └── If offline: compile locally on yifuwuqi             │
│                                                             │
│  2. nix-eval-jobs: evaluate once, skip cached jobs          │
│  3. One nix build --keep-going -L over all uncached jobs    │
│  4. attic push yi:yi every job that built; report per job   │
└─────────────────────────────────────────────────────────────┘
```

______________________________________________________________________

## 2. Forgejo Workflow Specification (`.forgejo/workflows/ci.yml`)

The primary CI pipeline runs on Forgejo Actions:

- **Triggers**: Pushes to `main` and `develop`, pull requests, and manual `workflow_dispatch`.
- **Concurrency**: Groups runs by `ci-${{ github.ref }}` and cancels superseded in-progress runs on feature branches / PRs (preserving runs on `main` and `develop`).
- **`build` Job (`Build & Cache`)**: Runs `ci/build.sh` on the native runner, which evaluates `.#hydraJobs` once with `nix-eval-jobs` (2 workers, `--show-trace`) and builds every uncached job in a single `nix build --keep-going --print-build-logs`.
  - Jobs (`nix/ci.nix`): all `checks` (`pre-commit`, `treefmt`, `yijia`), plus `nixos-<host>`, `package-<name>`, and `shell-<name>`.
  - Failure isolation: Nix caches no build failures, so per-job builds would each retry a broken dependency shared by several hosts. In one `--keep-going` build it is attempted once, its dependents fail immediately, and every job that does not depend on it still builds, gets pushed, and (on `develop`) gets its GC root. Nothing is retried.
  - Logs: every build line streams live, prefixed with its derivation name (`atuin> …`), along with the `building '…' on 'ssh-ng://yitaishi'` lines and the full error tail. `-v` is left off because it only adds one hard-link line per store file.
  - Output: Jobs that built are pushed to Attic after the build. A per-job `cached` / `built` / `failed` / `eval-error` table is printed to the log (Forgejo discards `$GITHUB_STEP_SUMMARY`) and written to the step summary, and the run fails if any job failed.

______________________________________________________________________

## 3. Remote Builder Probing (`ci/build.sh`)

The build script features automatic network discovery:

1. Tests TCP connectivity to `yitaishi` on port `24212` via Tailscale (`yitaishi.ts`) or NetBird (`yitaishi.nb`) with a 2-second timeout:
   ```bash
   timeout 2 bash -c '</dev/tcp/yitaishi.ts/24212'
   ```
1. **If Reachable**: Registers `yitaishi` as a high-speed remote builder (`ssh-ng://yitaishi x86_64-linux - 16 100 kvm,nixos-test,benchmark,big-parallel`).
1. **If Unreachable**: Outputs `yitaishi is offline. Proceeding without it.` and builds locally on `yifuwuqi`.

______________________________________________________________________

## 4. Self-Hosted Runners Configuration

### 4.1 Forgejo Native Runner (`modules/services/forgejo-runner.nix`)

- **Instance**: `forgejo-runner-yifuwuqi` running on `yifuwuqi`.
- **Labels**: `["native:host"]`.
- **Execution User**: `nix-builder:nogroup`.
- **Sandboxing Policy**: Default systemd sandboxing (`ProtectSystem`, `ProtectHome`, `PrivateUsers`, `PrivateMounts`) is explicitly relaxed so builds can interact directly with `/nix/store` and utilize Linux mount namespaces. Untrusted auto-maintenance evaluation, builds, and AI repair steps drop privileges via `/run/wrappers/bin/drop-to-none` (util-linux `setpriv` as a setuid/setgid `none:none` wrapper, executable only by group `none`) into an isolated `bubblewrap` mount namespace without access to `/var/lib/nix-builder/.ssh/id_ed25519`, Attic credentials, or `nix-daemon` `trusted-users` capabilities; an nftables output rule keeps that uid off loopback, LAN and tailnet addresses (see [Auto-Maintenance Bot](auto-maintenance.md)).
- **Attic Push Integration**: Injects `ATTIC_INTERNAL_URL = "http://yifuwuqi:24203"` and `ATTIC_CACHE_NAME = "yi"` into the runner environment.

### 4.2 GitHub Actions Runner (`modules/services/github-runner.nix`)

- **Target Repository**: `https://github.com/categoricalcat/nixos`.
- **User**: `nix-builder:nogroup`.
- **Environment Setup**: Runs `setup-ci-env` helper script on initialization to map internal URLs.
- **Secrets**: Token provisioned via Sops-nix (`tokens/github-runner-nixos`).

______________________________________________________________________

## 5. Gang Deployment & CI/CD Deployment Key (`.forgejo/workflows/cd.yml`)

The automated gang deployment pipeline runs via `deploy-rs` on Forgejo Actions using `ci/deploy.sh`.

### 5.1 Identity & Security Model

- **Runner Identity**: `nix-builder:nogroup` on `yifuwuqi`.
- **Private Key**: SOPS delivers a dedicated ed25519 key to `/var/lib/nix-builder/.ssh/id_ed25519` (`0400 nix-builder:nogroup`).
- **Public Key**: Registered in `secrets/keys.nix` as `keys.ci.deployPublicKey` and authorized in `users.users.root.openssh.authorizedKeys.keys` gang-wide.
- **Least Privilege**: The CI deployment key is **not** an age recipient in `.sops.yaml` / `sopsAgeRecipients`. CI can activate configurations via `deploy-rs`, but cannot decrypt SOPS secrets or read host keys.
- **Operator Lane**: Operator deployment remains root-only (`su -` then `deploy`) via `/persist/keys/ssh/ssh_host_ed25519_key` (resolved automatically via SSH `Match localuser root User root`). CI runner uses its standard `~/.ssh/id_ed25519`.

### 5.2 Rollout & Safety

- **Multi-host Batch Deployments**: The manual dispatch modal uses checkboxes for all target hosts (`yixiaoqing`, `yitaishi`, `yifuwuqi`, `yirukou`) and an `all` toggle, allowing batch deployments of any combination of machines in a single workflow run. When run interactively in a terminal without arguments, `ci/deploy.sh` launches an `fzf -m` multi-select prompt.
- **Per-host Failure Isolation**: `ci/deploy.sh` runs each host in its own errexit subshell. A failing host gets an `::error::` line and is skipped; the remaining hosts still run. The script writes the hosts that passed to `$GITHUB_OUTPUT` as `hosts` and exits non-zero if any host failed. In the single `cd.yml` job, each step (`gate` → `dry-activate` → `diff` → activation) receives only the hosts that passed the step before it, through `if: ${{ !cancelled() && … }}`. A host that fails preflight is never activated, the other hosts are, and the run still ends red. Forgejo drops the outputs of failed jobs, so preflight and activation cannot be split into two jobs.
- **Attic Gate**: Step 1 runs `ci/deploy.sh gate <host...>`, which drops any host whose toplevel closure is not yet verified in Attic. `nix.registry.self` embeds the flake source, so this only passes once CI has built that exact commit, which is why `ci/deploy.sh` runs deploy-rs with `--skip-checks`.
- **`dry` (Dry-run & Diff)**: Dry-runs activation (`ci/deploy.sh dry-activate <host...>`), verifies closure differences (`ci/deploy.sh diff <host...>`), and publishes a Markdown step summary (`$GITHUB_STEP_SUMMARY`) with target host metadata, store paths, and the full `nvd diff` output for every selected machine.
- **`switch` (Live Activation)**: Performs dry/diff verification, then live activation with `magicRollback` enabled (30s confirm timeout) via `ci/deploy.sh switch <host...>` and records the activation verdict in `$GITHUB_STEP_SUMMARY`.
- **`boot` (Bootloader Staging)**: Performs dry/diff verification, then updates the bootloader to boot into the new profile on next reboot without immediate live activation via `ci/deploy.sh boot <host...>` (`deploy .#<host> --boot`).
- **Runner Host Caution & Ordering**: `forgejo-runner-yifuwuqi.service` sets `restartIfChanged = false`, so activating `yifuwuqi` from CI no longer kills the job mid-activation. The deployment script automatically sorts target nodes so that `yifuwuqi` is activated last, after the remote nodes have finished (a failed remote node does not hold it back). Runner changes take effect after `systemctl restart forgejo-runner-yifuwuqi` (as root, while idle) or a reboot.

### 5.3 Key Rotation

To rotate the CI deployment key (as `root` via `su -` in `/home/yi/the.files/nixos`):

```bash
# 1. Mint a new key on any configured host
./users/scripts/setup-sops.sh [--rotate]

# 2. Update keys.ci.deployPublicKey in secrets/keys.nix

# 3. Ingest private key into SOPS
sops set secrets/secrets.yaml '["keys"]["deploy"]' "$(jq -Rs . < /run/ci-deploy-key/keys/deploy_ed25519)"
shred -u /run/ci-deploy-key/keys/deploy_ed25519
rm -rf /run/ci-deploy-key

# 4. Sync persist secrets and deploy across gang
./users/scripts/setup-sops.sh
```

______________________________________________________________________

## 6. Key Source Files

- `.forgejo/workflows/ci.yml`
- `.forgejo/workflows/cd.yml`
- `nix/deploy.nix`
- `nix/ci.nix`
- `ci/build.sh`
- `ci/deploy.sh`
- `modules/services/forgejo-runner.nix`
- `modules/services/github-runner.nix`
- `modules/services/attic/server.nix`
