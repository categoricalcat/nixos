# NixOS Build Deployment Strategy & Architecture Plan (Tailscale-IP OpenSSH & Zero-Ambient-Root)

## Objective

Design and implement a unified, robust, safe, and effortless deployment strategy to deploy NixOS system closures across all NixOS hosts in the mesh (`yifuwuqi`, `yirukou`, `yitaishi`, `yixiaoqing`), leveraging distributed builds, the Attic binary cache (`cache.fufu.land/yi`), and **OpenSSH (`sshd`) listening on Tailscale IP addresses (`100.69.0.x:24212`)**.

This plan is explicitly engineered to be **implemented and rolled out BEFORE the unprivileged daily user and global sudo removal architecture** (\[`docs/src/plans/remove-yi-from-wheel-plan.md`\](file:///home/yi/the.files/nixos/docs/src/plans/remove-yi-from-wheel-plan.md)):

- Implementing Deploy-rs first establishes a proven, reliable deployment lane protected by **Magic Rollback** across the entire mesh.
- Once Deploy-rs is operational over Tailscale IP OpenSSH endpoints, the subsequent sensitive changes in `remove-yi-from-wheel-plan.md` (removing `yi` from `wheel`, disabling `sudo`, locking server root accounts) can be deployed safely host-by-host using Deploy-rs with zero risk of irreversible lockout.
- All deployment traffic routes over **Tailscale**: all hosts listen on OpenSSH (`sshd`) on their Tailscale IP (`100.69.0.x:24212`). Deployments use OpenSSH, while servers (`yifuwuqi`, `yirukou`) also keep Tailscale SSH (`yi.tailscale.ssh = true`) active purely as an emergency backup/rescue lane.
- The human operator triggers deployments effortlessly from their standard user shell or via Forgejo Actions without manual multi-machine `su -` root dances.
- Non-system configurations (`yichuang` WSL and `yijia` Home Manager) build locally and are excluded from remote fleet deployment.
- **Every deploy is manual, one host at a time, preceded by a two-step dry-run diff check (`deploy --dry-activate`) and protected by Deploy-rs Magic Rollback.**

______________________________________________________________________

## Current State

```text
┌─────────────────────────────────────────────────────────────┐
│                          Git & CI                           │
│  ┌─────────────────────────┐     ┌───────────────────────┐  │
│  │   GitHub / Forgejo      ├────►│  CI Runner (yifuwuqi) │  │
│  │   (Push / PR Events)    │     │  (user: nix-builder)  │  │
│  └─────────────────────────┘     └───────────┬───────────┘  │
└──────────────────────────────────────────────┼──────────────┘
                                               │ ci/build.sh
┌──────────────────────────────────────────────▼──────────────┐
│                     Build & Cache Mesh                      │
│  ┌─────────────────────────┐     ┌───────────────────────┐  │
│  │ yifuwuqi (Build Host)   │◄───►│ yitaishi (Remote Bld) │  │
│  │ 100.69.0.6 / 10.42.0.2  │     │ 100.69.0.4            │  │
│  └───────────┬─────────────┘     └───────────────────────┘  │
│              │ push                                         │
│  ┌───────────▼─────────────┐                                │
│  │ Attic Binary Cache      │                                │
│  │ (cache.fufu.land/yi)    │                                │
│  └───────────┬─────────────┘                                │
└──────────────┼──────────────────────────────────────────────┘
               │ substitutes over Tailscale (100.69.0.0/10) & LAN
┌──────────────▼──────────────────────────────────────────────┐
│                    Tailscale Target Fleet                   │
│  • yirukou (100.69.0.1:24212 / 10.42.0.1)                   │
│  • yixiaoqing (100.69.0.3:24212)                            │
│  • yitaishi (100.69.0.4:24212)                              │
│  • yifuwuqi (100.69.0.6:24212 / 10.42.0.2)                  │
└─────────────────────────────────────────────────────────────┘
```

1. **Build & Cache Infrastructure**:
   - `ci/build.sh` on `yifuwuqi` builds all `nixosConfigurations.<host>.config.system.build.toplevel` closures and offloads compilation to `yitaishi` over SSH when online.
   - Attic binary cache (`cache.fufu.land/yi`) stores pre-built derivations.
   - Every host includes `cache.fufu.land/yi` in `nix.settings.substituters` via `modules/services/attic/client.nix`.
1. **CI Pipeline (Build & Cache Only)**:
   - `.forgejo/workflows/flake-ci.yml` runs on the native runner under the unprivileged `nix-builder:nogroup` user.
   - CI builds closures and pushes them to Attic. **CI never deploys and holds no root SSH keys or ambient deployment credentials.**
1. **Privilege & Authentication Evolution**:
   - With `remove-yi-from-wheel-plan.md`, `yi` is removed from `wheel`, `sudo` is disabled, and `yi` is not a trusted Nix daemon user.
   - Legacy deploy workflows relying on `sudo nixos-rebuild` or `--use-remote-sudo` are deprecated.
   - Tailscale mesh networking and OpenSSH binding provide cryptographic transport across all machines.

______________________________________________________________________

## Decisions

### 1. Tailscale IP as the Universal Transport Backbone

- **Dedicated Tailscale IP Binding**: All fleet nodes (`yifuwuqi`, `yirukou`, `yitaishi`, `yixiaoqing`) bind OpenSSH (`sshd`) to their Tailscale IPv4 address (`100.69.0.x:24212`). Deployments strictly target OpenSSH over the Tailscale IP.
- **Backup Rescue Lane**: Servers (`yifuwuqi`, `yirukou`) enable Tailscale SSH (`yi.tailscale.ssh = true`) as a backup/lockout recovery mechanism, separate from the primary deploy lane.
- **Cryptographic Mesh Transport**: Deployments and administrative commands route point-to-point over WireGuard/Tailscale to OpenSSH daemon on port 24212.
- **Zero-Trust Network Isolation**: Nodes communicate directly point-to-point over WireGuard, bypassing exposed public interfaces.

### 2. Two-Step Manual Deployment Pipeline in Forgejo Actions

- **Two-Step Pipeline (`.forgejo/workflows/deploy.yml`)**: Provides a `workflow_dispatch` button with manual inputs:
  - `host`: `yixiaoqing` | `yitaishi` | `yifuwuqi` | `yirukou` (strictly NixOS system nodes).
  - `step`: `1-diff` (default) | `2-deploy`.
- **Step 1 (`1-diff`)**: Runs `deploy .#<host> --dry-activate` to preview systemd unit changes and evaluation without activating.
- **Step 2 (`2-deploy`)**: Runs the dry-run diff check first, followed immediately by live activation `deploy .#<host>` protected by Magic Rollback.
- **Per-Host Concurrency**: `concurrency.group: deploy-${{ inputs.host }}` ensures non-overlapping execution.

### 3. Upstream Tooling & Zero Custom Scripts Policy

To maximize reliability, avoid maintenance overhead, and preserve standard shell completions and CLI flags:

- **No Custom Wrapper Scripts**: We explicitly avoid custom bash wrapper scripts (e.g. `ci/deploy.sh` is omitted in favor of calling upstream `deploy` directly).
- **Direct Upstream CLI**: Deployments use the official `deploy-rs` CLI (`deploy`) provided in `devShells.default.packages` and runner packages.
- **Native Subcommands & Verification**:
  - `deploy .#<host>`: Deploys system closure with automatic magic rollback.
  - `deploy .#<host> --dry-activate`: Evaluates and executes dry-activation without switching system state.
  - `nix flake check`: Validates flake evaluation and deploy-rs node schemas natively.

### 4. Deploy-rs with Magic Rollback & Watchdog Protection

- **Deploy-rs Targets**:
  - `profiles.system`: Configured with `user = "root"`, `sshUser = "root"`, and `path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.<host>`.
- **Magic Rollback**:
  - Enabled on all system profile nodes (`magicRollback = true`, `autoRollback = true`, `confirmTimeout = 30`).
  - If a deployment breaks networking, firewall rules, routing, or SSH access (critical for `yirukou` and `yifuwuqi`), the target node automatically reverts to the previous working system generation after the 30-second watchdog timer expires.
- **Fast Binary Substitution**: Target nodes pull pre-built derivations directly from the local Attic cache (`cache.fufu.land/yi`) over Tailscale/LAN during activation.

### 5. Tiered Rollout Discipline (Operator Blast Radius Containment)

Deployments are executed manually, one host at a time, adhering to a tiered rollout sequence:

```text
┌─────────────────────────────────────────────────────────────┐
│             Tier 1: Non-Critical / Dev Nodes                │
│  • yitaishi (Workstation / Remote Builder)                  │
│  • yixiaoqing (Laptop)                                      │
└──────────────────────────────┬──────────────────────────────┘
                               │ Verify stability
┌──────────────────────────────▼──────────────────────────────┐
│                    Tier 2: Core Server                      │
│  • yifuwuqi (Attic, Forgejo, DNS Secondary, Core Services)   │
└──────────────────────────────┬──────────────────────────────┘
                               │ Verify services & DNS
┌──────────────────────────────▼──────────────────────────────┐
│                Tier 3: Critical Edge Router                 │
│  • yirukou (Gateway, WAN, DHCP, Firewall, Nginx Proxy)      │
└─────────────────────────────────────────────────────────────┘
```

______________________________________________________________________

## Fleet Target Matrix

| Host             | Tailscale IP | SSH Endpoint       | Profile Type | Activation User | Rollback Watchdog              |
| :--------------- | :----------- | :----------------- | :----------- | :-------------- | :----------------------------- |
| **`yitaishi`**   | `100.69.0.4` | `100.69.0.4:24212` | System       | `root`          | `magicRollback = true`         |
| **`yixiaoqing`** | `100.69.0.3` | `100.69.0.3:24212` | System       | `root`          | `magicRollback = true`         |
| **`yifuwuqi`**   | `100.69.0.6` | `100.69.0.6:24212` | System       | `root`          | `magicRollback = true` (`30s`) |
| **`yirukou`**    | `100.69.0.1` | `100.69.0.1:24212` | System       | `root`          | `magicRollback = true` (`30s`) |

______________________________________________________________________

## Phases

### Phase 1: Dedicated Flake-Parts Deploy Module & Deploy-rs Schema

- Add `deploy-rs` to `inputs` in `flake.nix`.
- Create dedicated `nix/deploy.nix` flake-parts module defining `deploy.nodes` schema covering all 4 system hosts (`yifuwuqi`, `yirukou`, `yitaishi`, `yixiaoqing`), binding hostnames to their Tailscale IPv4 addresses and SSH ports (`100.69.0.x:24212`).
- Configure `autoRollback = true`, `magicRollback = true`, and `confirmTimeout = 30` for system profiles.
- Add `deployChecks` to `perSystem.checks` in `nix/deploy.nix`.

### Phase 2: OpenSSH Daemon over Tailscale IP Binding

- Ensure OpenSSH daemon (`sshd`) on every host binds to its Tailscale IP (`addresses.ssh.listenAddresses` includes `network.tailscale.ipv4.host` on port `24212`).
- Ensure `sshd.service` systemd dependencies include `after = [ "tailscaled.service" ]` when Tailscale is enabled.
- Servers (`yifuwuqi`, `yirukou`) retain `yi.tailscale.ssh = true` as an out-of-band backup rescue lane.

### Phase 3: Two-Step Forgejo Actions Deploy Workflow

- Create `.forgejo/workflows/deploy.yml` declaring the two-step manual pipeline (`1-diff` and `2-deploy`) with single-host choices and concurrency locks.
- Add `deploy-rs` to `modules/services/forgejo-runner.nix` hostPackages and `nix/devshell.nix`.
- Avoid custom script wrappers, calling upstream `deploy` directly.

### Phase 4: Validation & Rollout Alignment

- Perform validation in synchronization with \[`docs/src/plans/remove-yi-from-wheel-plan.md`\](file:///home/yi/the.files/nixos/docs/src/plans/remove-yi-from-wheel-plan.md):
  1. Run `nix flake check` to validate deploy schemas.
  1. Run `deploy .#yitaishi --dry-activate` to test non-destructive remote evaluation and diff preview.
  1. Deploy canary system closure to `yitaishi` and `yixiaoqing` via `deploy .#<host>` (or Forgejo Actions Step 2).
  1. Deploy to `yifuwuqi` and verify core services and Attic cache availability.
  1. Deploy to `yirukou` with active ping verification and magic rollback armed.

______________________________________________________________________

## Rollout Order

1. **`yitaishi` / `yixiaoqing` (Tier 1)**: Dev & Workstation nodes — dry-activate, inspect, and deploy one host at a time over Tailscale.
1. **`yifuwuqi` (Tier 2)**: Core services, Forgejo, and Attic binary cache.
1. **`yirukou` (Tier 3)**: Critical perimeter router and gateway (supervised with magic rollback).

______________________________________________________________________

## Open Questions

- **Question 1 (SSH Authentication Lane)**: Resolved. All deployment transport routes over Tailscale WireGuard directly to OpenSSH (`sshd`) listening on the Tailscale IP on port 24212, while servers keep Tailscale SSH as backup.
- **Question 2 (Tooling and Scripts)**: Resolved. Strictly avoid custom wrapper scripts. Use upstream `deploy-rs` CLI (`deploy`), `nix flake check`, and standard `deploy --dry-activate`.
