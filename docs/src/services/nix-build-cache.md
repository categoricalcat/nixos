# Nix Distributed Builds & Binary Cache Mesh

This guide documents the distributed build infrastructure, pinned host-key mesh authentication, and binary cache integration across the NixOS gang.

______________________________________________________________________

## 1. How The Build Mesh Works

```text
┌─────────────────────────────────────────────────────────────┐
│                       Client Request                        │
│             (e.g., yixiaoqing laptop switching)             │
└──────────────────────────────┬──────────────────────────────┘
                               │ nixos-rebuild --build-host yifuwuqi
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 yifuwuqi (Primary Build Host)               │
│  • Coordinates derivation evaluation & compilation          │
│  • Pushes built closures to Attic binary cache              │
│  • Max parallel jobs: 16                                    │
└──────────────┬──────────────────────────────▲───────────────┘
               │ offloads heavy derivations   │ returns built paths
               ▼                              │
┌─────────────────────────────────────────────┴───────────────┐
│              yitaishi (High-Power Remote Builder)           │
│  • 16 CPU cores, speedFactor: 360                           │
│  • AMD Radeon RX 7900 XTX acceleration                      │
└─────────────────────────────────────────────────────────────┘
```

- **Primary Build Host (`yifuwuqi`)**: Accepts build delegations over SSH from clients, offloads compilation to configured remote builders, and stores resulting paths in the local Nix store.
- **High-Performance Worker (`yitaishi`)**: Remote worker configured with `speedFactor = 360` to accelerate parallel C++/Rust/Linux kernel builds.
- **Client Nodes (`yixiaoqing`, `yichuang`)**: Request closures from `yifuwuqi`, minimizing laptop battery drain (`yirukou` deploys prebuilt closures remotely via `deploy-rs` with distributed builds disabled).

______________________________________________________________________

## 2. Pinned SSH Host Key Authentication

Nix distributed builds authenticate over SSH using the dedicated `nix-builder` user and pinned ED25519 host keys:

### 2.1 Security Model

- **No Trust-On-First-Use (TOFU)**: `/etc/ssh/ssh_known_hosts` is generated deterministically by `modules/services/ssh/known-hosts.nix` from `secrets/keys.nix` and `modules/addresses.nix`.
- **Locked-Down User**: The `nix-builder` user is restricted via SSH `ForceCommand nix-daemon --stdio` with all TTY, port forwarding, agent forwarding, and X11 forwarding disabled.
- **Trusted Nix User**: `nix-builder` is listed in `nix.settings.trusted-users` on build servers, permitting direct communication with the Nix daemon.

### 2.2 Adding a Host to the Mesh

1. **Record the machine block printed by `setup-sops` in
   `secrets/keys.nix` and add its name to `keyed`**:
   ```nix
   newhost = {
     host = {
       ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...";
       age = "age1...";
     };
     # yi, ai, and allow are printed by setup-sops
   };
   ```
1. **Configure `nixBuild` in `modules/addresses/hosts.nix`** (`supportedFeatures`
   and `mandatoryFeatures` are derived in `modules/distributed-builds.nix`):
   ```nix
   nixBuild = mkNixBuild {
     remoteBuilder = false;
     maxJobs = 8;
     speedFactor = 100;
   };
   ```
1. **Deploy the configuration (as `root` via `su -`)**:
   ```bash
   su -
   nh os switch /home/yi/the.files/nixos
   ```

______________________________________________________________________

## 3. Attic Binary Cache Integration

Every host in the gang automatically imports `modules/services/attic/client.nix` via `modules/nix-settings.nix`:

- **Substituter URL**: `https://cache.aset.love/yi` (atticd binds loopback behind the `yifuwuqi` local ingress; on-host clients use `http://127.0.0.1:24203/yi`)
- **Pinned Public Key**: `yi:wLUC4OacKKUxGtnXwIxTFGBlLwvJ9IU4BNP5OBDQO60=`

When any machine activates a new system generation, pre-built store paths are substituted from Attic rather than re-compiled locally.

______________________________________________________________________

## 4. Daily Build & Switch Workflows

### 4.1 Switch a Client Locally (Offloading via `nix-daemon`)

From a client machine (`yitaishi` or `yixiaoqing`), elevate to `root` (`su -`) and run `nh os switch` (`nix.distributedBuilds` automatically offloads derivations to `yifuwuqi` and `yitaishi` using `/persist/keys/ssh/ssh_host_ed25519_key` and `nix-builder`):

```bash
su -
nh os switch /home/yi/the.files/nixos
```

### 4.2 Deploy Remotely from a Client Root Shell

From `yitaishi` or `yixiaoqing`, elevate to `root` (`su -`) and deploy to a server (`yifuwuqi`, `yirukou`) using `deploy-rs` (authenticating with the client's host SSH key `/persist/keys/ssh/ssh_host_ed25519_key`):

```bash
su -
cd /home/yi/the.files/nixos
deploy .#yifuwuqi
```

______________________________________________________________________

## 5. Developer Shell Inspection Tools (`nix/devshell.nix`)

Entering `nix develop` (both default and `.#sandbox`) launches the configured `zsh`, `starship`, TUI, and `git`/`delta` shell environment from `users/home/shell.nix` and `users/programs/git.nix`; that works even on minimal hosts without Home Manager. Besides the linters and the custom helper utilities/dev-AI wrappers (`nxd-agy`, `nxd-agent`, `nxd-opencode`, `seenix`, `diff-to-commit`, `lock-to-changelog`, `nixos-rebuild`, `git`, `neovim`), the shell carries the general CLI suite from `nix/cli-tools.nix` (e.g. `bat`, `ncdu`, `tree`, `fd`, `ripgrep`, archives) that no host installs system-wide, plus the network and container admin tools (e.g. `nmap`, `tcpdump`, `iftop`, `nethogs`, `iperf3`, `traceroute`, `ethtool`, `podman-compose`, `skopeo`, `dive`, `buildah`). The inspection scripts below are also on PATH:

| Command             | Purpose                                                                       |
| ------------------- | ----------------------------------------------------------------------------- |
| `host-tree <host>`  | Interactive visualizer for system closure dependencies using `nix-tree`       |
| `host-size <host>`  | Lists the top 25 largest packages in a host's system closure                  |
| `host-diff <host>`  | Compares package changes between current generation and new build using `nvd` |
| `host-dead`         | Scans for dead code and statix linting warnings across the flake              |
| `dns-warm`          | Pre-warms the recursive Unbound DNS cache using top Majestic Million domains  |
| `diff-to-commit`    | Generates AI commit messages from staged Git diffs                            |
| `lock-to-changelog` | Generates AI patch notes from all updated inputs in `flake.lock`              |
| `inspect <host>`    | Drops into an interactive Nix REPL with the host configuration loaded         |

______________________________________________________________________

## 6. Key Source Files

- `modules/distributed-builds.nix`
- `modules/services/ssh/default.nix`
- `modules/services/ssh/known-hosts.nix`
- `modules/services/attic/client.nix`
- `modules/addresses.nix`
- `secrets/keys.nix`
- `nix/devshell.nix`
- `ci/build.sh`
