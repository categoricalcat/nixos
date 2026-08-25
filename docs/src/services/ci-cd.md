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

## 5. Key Source Files

- `.forgejo/workflows/flake-ci.yml`
- `ci/build.sh`
- `modules/services/forgejo-runner.nix`
- `modules/services/github-runner.nix`
- `modules/services/attic/server.nix`
