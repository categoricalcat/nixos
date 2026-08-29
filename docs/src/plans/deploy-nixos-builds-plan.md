# NixOS Build Deployment Strategy & Architecture Plan (Tailscale-First & Zero-Ambient-Root)

## Objective

Design and implement a unified, robust, safe, and effortless deployment strategy to deploy NixOS system closures and Home Manager profiles across all hosts in the mesh (`yifuwuqi`, `yirukou`, `yitaishi`, `yixiaoqing`, `yichuang`, `yijia`), leveraging distributed builds, the Attic binary cache (`cache.fufu.land/yi`), and **Tailscale mesh networking / Tailscale SSH**.

This plan is explicitly engineered to be **implemented and rolled out BEFORE the unprivileged daily user and global sudo removal architecture** (\[`docs/src/plans/remove-yi-from-wheel-plan.md`\](file:///home/yi/the.files/nixos/docs/src/plans/remove-yi-from-wheel-plan.md)):

- Implementing Deploy-rs first establishes a proven, reliable deployment lane protected by **Magic Rollback** across the entire mesh.
- Once Deploy-rs is operational over Tailscale, the subsequent sensitive changes in `remove-yi-from-wheel-plan.md` (removing `yi` from `wheel`, disabling `sudo`, locking server root accounts) can be deployed safely host-by-host using Deploy-rs with zero risk of irreversible lockout.
- All deployment traffic and authentication route over **Tailscale**: all hosts listen on SSH on their Tailscale IP (`100.69.0.x:24212`) and enable Tailscale SSH (`yi.tailscale.ssh = true`).
- The human operator triggers deployments effortlessly from their standard user shell over Tailscale without manual multi-machine `su -` root dances.
- **Every deploy is manual, one host at a time, preceded by verification (`deploy --dry-activate` / `nvd diff`) and protected by Deploy-rs Magic Rollback.**

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
│  • yichuang (WSL Environment)                               │
│  • yijia (Home Manager Profile)                             │
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
   - Tailscale mesh networking and Tailscale SSH provide cryptographic identity verification and secure transport across all machines.

______________________________________________________________________

## Decisions

### 1. Tailscale as the Universal Transport & Authentication Backbone

- **Dedicated Tailscale IP Binding**: All fleet nodes (`yifuwuqi`, `yirukou`, `yitaishi`, `yixiaoqing`) bind OpenSSH to their Tailscale IPv4 address (`100.69.0.x:24212`) and enable Tailscale SSH (`yi.tailscale.ssh = true`).
- **Cryptographic Tailnet Identity**: Deployments and administrative commands authenticate via Tailscale WireGuard keys and Tailscale ACLs.
- **Zero-Trust Network Isolation**: Nodes communicate directly point-to-point over WireGuard, bypassing exposed public interfaces.

### 2. Clean Separation: CI Builds & Caches, Operator Deploys

- **CI / Forgejo Runner (`nix-builder`)**: Strictly responsible for continuous integration, evaluation checks (`nix flake check`), compilation (`ci/build.sh`), and pushing derivations to Attic. The runner possesses zero ambient root elevation and no deployment SSH keys.
- **Operator-Driven Deploys**: All deployments are triggered by the human operator from their daily terminal environment.

### 3. Effortless Unprivileged Operator Workflow (`yi`)

- The operator runs deployments directly from their normal user shell as `yi` using the `deploy` CLI / `deploy-rs`.
- Because authentication and authorization are validated cryptographically via Tailscale (or OpenSSH over Tailscale), the operator does **not** need to perform complex manual `su -` root logins or password entries across multiple machines.
- `sudo` remains completely disabled across the fleet (`security.sudo.enable = false;`).

### 4. Upstream Tooling & Zero Custom Scripts Policy

To maximize reliability, avoid maintenance overhead, and preserve standard shell completions and CLI flags:

- **No Custom Wrapper Scripts**: We explicitly avoid creating custom bash deployment scripts (e.g., custom `deploy` scripts or wrappers in `nix/scripts/`).
- **Direct Upstream CLI**: Deployments use the official `deploy-rs` CLI (`deploy`) provided directly in `devShells.default.packages`.
- **Native Subcommands & Verification**:
  - `deploy .#<host>`: Deploys system closure with automatic magic rollback.
  - `deploy .#<host> --dry-activate`: Evaluates and executes dry-activation without switching system state.
  - `deploy .#<host> --targets .#<host>.system`: Directly targets specific profiles.
  - `nix flake check`: Validates flake evaluation and deploy-rs node schemas natively.
  - `nvd diff <current-closure> <new-closure>`: Invoked directly when explicit package-level diffing is desired.
- **Declarative SSH Transport**: Dynamic host resolution and port configuration (`24212`) are managed by declarative SSH configs (`programs.ssh` / `modules/services/ssh/dynamic.nix`), eliminating ad-hoc connection logic in scripts.

### 5. Deploy-rs with Magic Rollback & Watchdog Protection

- **Deploy-rs Targets**:
  - `profiles.system`: Configured with `user = "root"`, `sshUser = "root"`, and `path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.<host>`.
  - `profiles.yijia`: Configured with `user = "yi"`, `sshUser = "yi"`, and `path = deploy-rs.lib.x86_64-linux.activate.home-manager self.homeConfigurations.yijia`.
- **Magic Rollback**:
  - Enabled on all system profile nodes (`magicRollback = true`, `autoRollback = true`, `confirmTimeout = 30`).
  - If a deployment breaks networking, firewall rules, routing, or SSH access (critical for `yirukou` and `yifuwuqi`), the target node automatically reverts to the previous working system generation after the 30-second watchdog timer expires.
- **Fast Binary Substitution**: Target nodes pull pre-built derivations directly from the local Attic cache (`cache.fufu.land/yi`) over Tailscale/LAN during activation.

### 6. Tiered Rollout Discipline (Operator Blast Radius Containment)

Deployments are executed manually, one host at a time, adhering to a tiered rollout sequence:

```text
┌─────────────────────────────────────────────────────────────┐
│             Tier 1: Non-Critical / Dev Nodes                │
│  • yichuang (WSL local activation)                          │
│  • yijia (Home Manager profile via yi)                      │
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

| Host             | Tailscale IP | SSH Endpoint        | Profile Type | Activation User | Rollback Watchdog              |
| :--------------- | :----------- | :------------------ | :----------- | :-------------- | :----------------------------- |
| **`yichuang`**   | WSL          | Local WSL           | System       | Local WSL root  | N/A                            |
| **`yijia`**      | Mesh         | `yitaishi.ts:24212` | Home Manager | `yi`            | `autoRollback = true`          |
| **`yitaishi`**   | `100.69.0.4` | `100.69.0.4:24212`  | System       | `root`          | `magicRollback = true`         |
| **`yixiaoqing`** | `100.69.0.3` | `100.69.0.3:24212`  | System       | `root`          | `magicRollback = true`         |
| **`yifuwuqi`**   | `100.69.0.6` | `100.69.0.6:24212`  | System       | `root`          | `magicRollback = true` (`30s`) |
| **`yirukou`**    | `100.69.0.1` | `100.69.0.1:24212`  | System       | `root`          | `magicRollback = true` (`30s`) |

______________________________________________________________________

## Phases

### Phase 1: Flake Integration & Deploy-rs Schema

- Add `deploy-rs` to `inputs` in `flake.nix`.
- Define `deploy.nodes` schema in `flake.nix` covering all hosts (`yifuwuqi`, `yirukou`, `yitaishi`, `yixiaoqing`, `yijia`), binding hostnames to their Tailscale endpoints (`<host>.ts` / `100.69.0.x:24212`).
- Configure `autoRollback = true`, `magicRollback = true`, and `confirmTimeout = 30` for system profiles.
- Add `deployChecks` to `perSystem.checks` in `flake.nix`.

### Phase 2: Tailscale SSH & Listener Configuration

- Verify that all hosts import `modules/services/tailscale.nix` and set `yi.tailscale.ssh = true`.
- Ensure OpenSSH on every host binds to its Tailscale IP (`addresses.ssh.listenAddresses` includes `network.tailscale.ipv4.host` on port `24212`).
- Ensure Tailscale ACLs authorize the operator's Tailscale identity for administrative access.

### Phase 3: Devshell & Upstream Tooling Integration

- Add `pkgs.deploy-rs` (or `inputs.deploy-rs.packages.${pkgs.system}.default`) directly to `devShells.default` packages in `nix/devshell.nix`.
- Do not create custom wrapper scripts; rely directly on `deploy`, `nix flake check`, `nvd`, and standard NixOS commands.

### Phase 4: Validation & Rollout Alignment

- Perform validation in synchronization with \[`docs/src/plans/remove-yi-from-wheel-plan.md`\](file:///home/yi/the.files/nixos/docs/src/plans/remove-yi-from-wheel-plan.md):
  1. Run `nix flake check` to validate deploy schemas.
  1. Run `deploy .#yitaishi --dry-activate` to test non-destructive remote evaluation.
  1. Deploy canary system closure to `yitaishi` and `yixiaoqing` via `deploy .#<host>`.
  1. Deploy to `yifuwuqi` and verify core services and Attic cache availability.
  1. Deploy to `yirukou` with active ping verification and magic rollback armed.

______________________________________________________________________

## Rollout Order

1. **`yitaishi` / `yixiaoqing` / `yichuang` / `yijia` (Tier 1)**: Dev & Workstation nodes — dry-activate, inspect, and deploy one host at a time over Tailscale.
1. **`yifuwuqi` (Tier 2)**: Core services, Forgejo, and Attic binary cache.
1. **`yirukou` (Tier 3)**: Critical perimeter router and gateway (supervised with magic rollback).

______________________________________________________________________

## Open Questions

- **Question 1 (SSH Authentication Lane)**: Resolved. All deployment transport and SSH authentication use Tailscale (Tailscale IP on port 24212 and Tailscale SSH), eliminating legacy `yi + sudo` and complex multi-machine `su -` requirements.
- **Question 2 (Tooling and Scripts)**: Resolved. Strictly avoid authoring custom wrapper scripts. Use upstream `deploy-rs` CLI (`deploy`), `nix flake check`, and standard `nvd diff`.
