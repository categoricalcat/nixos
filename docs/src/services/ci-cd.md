# CI/CD Pipeline & Actions Runners

This document details the automated continuous integration, matrix compilation, and binary cache publishing pipeline running on self-hosted Forgejo and GitHub Actions runners.

______________________________________________________________________

## 1. Pipeline Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                      Git Push / PR Event                    │
│             (to main, develop, or workflow_dispatch)        │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                    Job 1: Flake Check                       │
│    nix flake check --print-build-logs --show-trace -v       │
└──────────────────────────────┬──────────────────────────────┘
                               │ Success
┌──────────────────────────────▼──────────────────────────────┐
│             Job 2: Build & Push Matrix (max-parallel: 1)    │
│  Matrix: [yixiaoqing, yitaishi, yifuwuqi, yirukou, yichuang]│
│                                                             │
│  1. Run ci/build.sh <host>                                  │
│     ├── Probe yitaishi on port 24212 (Tailscale / NetBird)  │
│     ├── If online: offload derivations via ssh-ng           │
│     └── If offline: compile locally on yifuwuqi             │
│                                                             │
│  2. Push built system closure to Attic Binary Cache         │
│     attic push yi:yi result-<host>                          │
└─────────────────────────────────────────────────────────────┘
```

______________________________________________________________________

## 2. Forgejo Workflow Specification (`.forgejo/workflows/flake-ci.yml`)

The primary CI pipeline runs on Forgejo Actions:

- **Triggers**: Pushes to `main` and `develop`, pull requests, and manual `workflow_dispatch`.
- **`check` Job**: Runs syntax, flake integrity, and module evaluation tests on the native runner.
- **`buildepush` Job**:
  - Strategy: `max-parallel: 1` (builds one host at a time to prevent resource exhaustion) with `fail-fast: false`.
  - Matrix targets: `yixiaoqing`, `yitaishi`, `yifuwuqi`, `yirukou`, `yichuang`.
  - Output: Derivations land in `result-<host>` and are immediately pushed to Attic.

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

- **Instance**: `gitea-runner-yifuwuqi` running on `yifuwuqi`.
- **Labels**: `["native:host"]`.
- **Execution User**: `nix-builder:nogroup`.
- **Sandboxing Policy**: Default systemd sandboxing (`ProtectSystem`, `ProtectHome`, `PrivateUsers`, `PrivateMounts`) is explicitly relaxed so builds can interact directly with `/nix/store` and utilize Linux mount namespaces.
- **Attic Push Integration**: Injects `ATTIC_INTERNAL_URL = "http://yifuwuqi:18203"` and `ATTIC_CACHE_NAME = "yi"` into the runner environment.

### 4.2 GitHub Actions Runner (`modules/services/github-runner.nix`)

- **Target Repository**: `https://github.com/categoricalcat/nixos`.
- **User**: `nix-builder:nogroup`.
- **Environment Setup**: Runs `setup-ci-env` helper script on initialization to map internal URLs.
- **Secrets**: Token provisioned via Sops-nix (`tokens/github-runner-nixos`).

______________________________________________________________________

## 5. Fleet Deployment & CI/CD Deployment Key (`.forgejo/workflows/deploy.yml`)

The automated fleet deployment pipeline runs via `deploy-rs` on Forgejo Actions.

### 5.1 Identity & Security Model

- **Runner Identity**: `nix-builder:nogroup` on `yifuwuqi`.
- **Private Key**: SOPS delivers a dedicated ed25519 key to `/var/lib/nix-builder/.ssh/id_ed25519` (`0400 nix-builder:nogroup`).
- **Public Key**: Registered in `secrets/keys.nix` as `keys.ci.deployPublicKey` and authorized in `users.users.root.openssh.authorizedKeys.keys` fleet-wide.
- **Least Privilege**: The CI deployment key is **not** an age recipient in `.sops.yaml` / `sopsAgeRecipients`. CI can activate configurations via `deploy-rs`, but cannot decrypt SOPS secrets or read host keys.
- **Operator Lane**: Operator deployment remains root-only (`su -` then `deploy`) via `/persist/keys/ssh/ssh_host_ed25519_key` (resolved automatically via SSH `Match localuser root User root`). CI runner uses its standard `~/.ssh/id_ed25519`.

### 5.2 Rollout & Safety

- **Step 1 (`1-diff`)**: Dry-runs activation (`deploy .#<host> --dry-activate`) and verifies closure differences before applying changes.
- **Step 2 (`2-deploy`)**: Performs live activation with `magicRollback` enabled (30s confirm timeout).
- **Runner Host Caution**: When activating `yifuwuqi` from CI, changes that restart `gitea-runner-yifuwuqi.service` will kill the job mid-activation and trigger magic rollback. Apply runner service modifications from a local root terminal.

### 5.3 Key Rotation

To rotate the CI deployment key:

```bash
# 1. Mint new key on yifuwuqi (or run with --rotate)
./users/scripts/setup-sops.sh [--rotate]

# 2. Update keys.ci.deployPublicKey in secrets/keys.nix

# 3. Ingest private key into SOPS
sops set secrets/secrets.yaml '["keys"]["deploy"]' "$(jq -Rs . < /run/ci-deploy-key/keys/deploy_ed25519)"
shred -u /run/ci-deploy-key/keys/deploy_ed25519
rm -rf /run/ci-deploy-key

# 4. Sync persist secrets and deploy across fleet
```

______________________________________________________________________

## 6. Key Source Files

- `.forgejo/workflows/flake-ci.yml`
- `.forgejo/workflows/deploy.yml`
- `nix/deploy.nix`
- `ci/build.sh`
- `modules/services/forgejo-runner.nix`
- `modules/services/github-runner.nix`
- `modules/services/attic/server.nix`
