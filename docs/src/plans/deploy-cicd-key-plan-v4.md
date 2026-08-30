# Dedicated CI/CD Deployment Key & `setup-sops.sh` Refactoring Plan (v4 — automated setup)

Supersedes [deploy-cicd-key-plan.md](deploy-cicd-key-plan.md),
[deploy-cicd-key-plan-v2.md](deploy-cicd-key-plan-v2.md), and
[deploy-cicd-key-plan-v3.md](deploy-cicd-key-plan-v3.md).

v3 added an explicit `--ci-key` flag to `setup-sops.sh` on `yifuwuqi`. This v4 revision
streamlines `setup-sops.sh` to do the bare minimum functionally: run uniformly across
all hosts without a `--ci-key` flag. On `yifuwuqi`, if `keys.ci.deployPublicKey` is
missing from `secrets/keys.nix` (or if `--rotate` is passed), the script automatically
generates the CI key in tmpfs and outputs the SOPS ingestion instructions; on repeat runs
it does nothing extra.

## Objective

Give the Forgejo runner (`nix-builder`) its own SOPS-delivered ed25519 identity
so `deploy-rs` can activate the fleet from CI, **without** granting CI access to
`/persist/keys/ssh/ssh_host_ed25519_key` (which is simultaneously the host SSH
identity and the host SOPS age identity, see [secrets/sops.nix](../../../secrets/sops.nix)).

Keep `setup-sops.sh` fully uniform and minimal across all hosts without special flags
needed for initial deployment.

______________________________________________________________________

## Current State

1. **Runner**: `gitea-runner-yifuwuqi` runs as `nix-builder:nogroup`
   ([modules/services/forgejo-runner.nix](../../../modules/services/forgejo-runner.nix)).
   [.forgejo/workflows/deploy.yml](../../../.forgejo/workflows/deploy.yml) runs `deploy .#<host>`.
1. **`setup-sops.sh`**: Uses helper functions (`ensure_host_key`, `ensure_user_ssh_key`,
   `derive_age_key`, `ssh_pub_to_age`) and `runuser -u yi --`.
1. **CI key delivery & schema**: Declared in `forgejo-runner.nix` to
   `/var/lib/nix-builder/.ssh/id_ed25519`, authorized in root `authorizedKeys` in `users/users.nix`,
   and included in `nix/deploy.nix` `sshOpts`.

______________________________________________________________________

## Decisions

### 1. Zero-flag CI Key Handling in `setup-sops.sh`

- Drop `--ci-key`. The script accepts optional positional `[hostname]` and `--rotate`.
- When running on `yifuwuqi`:
  - Check if `keys.ci.deployPublicKey` with a valid `ssh-ed25519` key already exists in `secrets/keys.nix`.
  - If **missing** or if `--rotate` is passed: mint keypair in `/run/ci-deploy-key/keys/deploy_ed25519`
    (`0700 root:root`) and print the `keys.ci` snippet along with `sops set` instructions.
  - If **already registered** and `--rotate` is not passed: skip minting.
- On other hosts: skip CI key handling automatically.

### 2. Dedicated CI key, SOPS-delivered

- Private half stored in `secrets/secrets.yaml` under `keys/deploy`; public half in `secrets/keys.nix`.
- Delivered to `/var/lib/nix-builder/.ssh/id_ed25519` (`owner = "nix-builder"`, `mode = "0400"`).
- `systemd.tmpfiles.rules = [ "d /var/lib/nix-builder/.ssh 0700 nix-builder nogroup -" ]`.
- Ordered after `sops-nix.service`.
- The deploy key is **not** an age recipient.

### 3. Root authorization & `sshOpts`

- `users.users.root.openssh.authorizedKeys.keys` gains `keys.ci.deployPublicKey`.
- `nix/deploy.nix` includes both `-i ${keys.paths.sshHostKey}` and `-i "/var/lib/nix-builder/.ssh/id_ed25519"`.

______________________________________________________________________

## Phases

### Phase 1: Update `setup-sops.sh`

1. Remove `--ci-key` option.
1. Automate CI key detection on `yifuwuqi` (generate if missing or `--rotate`).

### Phase 2: Documentation

1. Update `docs/src/services/secrets.md` and `docs/src/services/ci-cd.md` to reference `./users/scripts/setup-sops.sh` (or `--rotate`).

### Phase 3: Switch & Verification

1. On `yifuwuqi`, run `./users/scripts/setup-sops.sh` to mint the key.
1. `sops set` into `secrets/secrets.yaml` and update `secrets/keys.nix`.
1. Switch `yifuwuqi` and verify CI auth.
1. Deploy to fleet and test CI runner.

______________________________________________________________________

## Rollout Order

1. **`yifuwuqi`**: Run `./users/scripts/setup-sops.sh`, ingest into SOPS, switch locally.
1. **Fleet**: Deploy remotes via operator lane (`deploy .#<host>`), then hand to CI.

______________________________________________________________________

## Open Questions

- None.
