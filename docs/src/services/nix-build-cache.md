# Nix Distributed Builds & Binary Cache Mesh

This guide documents the distributed build infrastructure, pinned host-key mesh authentication, and binary cache integration across the NixOS fleet.

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
- **Client Nodes (`yixiaoqing`, `yirukou`, `yichuang`)**: Request closures from `yifuwuqi`, minimizing laptop battery drain and router CPU usage.

______________________________________________________________________

## 2. Pinned SSH Host Key Authentication

Nix distributed builds authenticate over SSH using the dedicated `nix-builder` user and pinned ED25519 host keys:

### 2.1 Security Model

- **No Trust-On-First-Use (TOFU)**: `/etc/ssh/ssh_known_hosts` is generated deterministically by `modules/services/ssh/known-hosts.nix` from `secrets/keys.nix` and `modules/addresses.nix`.
- **Locked-Down User**: The `nix-builder` user is restricted via SSH `ForceCommand nix-daemon --stdio` with all TTY, port forwarding, agent forwarding, and X11 forwarding disabled.
- **Trusted Nix User**: `nix-builder` is listed in `nix.settings.trusted-users` on build servers, permitting direct communication with the Nix daemon.

### 2.2 Adding a Host to the Mesh

1. **Record the Host's Public SSH Key in `secrets/keys.nix`**:
   ```nix
   keys.hosts.newhost.sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...";
   ```
1. **Configure `nixBuild` in `modules/addresses.nix`**:
   ```nix
   nixBuild = {
     maxJobs = 8;
     speedFactor = 100;
     supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
     mandatoryFeatures = [ ];
   };
   ```
1. **Deploy the configuration**:
   ```bash
   nixos-rebuild switch --flake .#newhost
   ```

______________________________________________________________________

## 3. Attic Binary Cache Integration

Every host in the fleet automatically imports `modules/services/attic/client.nix` via `modules/nix-settings.nix`:

- **Substituter URL**: `https://cache.fufu.land/yi` (or direct LAN `http://10.42.0.2:24203/yi`)
- **Pinned Public Key**: `yi:wLUC4OacKKUxGtnXwIxTFGBlLwvJ9IU4BNP5OBDQO60=`

When any machine activates a new system generation, pre-built store paths are substituted from Attic rather than re-compiled locally.

______________________________________________________________________

## 4. Daily Build & Switch Workflows

### 4.1 Build Remotely, Switch Locally

From the client machine you wish to update (e.g. `yixiaoqing`):

```bash
sudo nixos-rebuild switch \
  --flake .#yixiaoqing \
  --build-host yi@yifuwuqi
```

### 4.2 Build and Deploy Remotely from a Workstation

From your desktop (`yitaishi`), build on `yifuwuqi` and deploy to a target node:

```bash
nixos-rebuild switch \
  --flake .#yixiaoqing \
  --build-host yi@yifuwuqi \
  --target-host yi@yixiaoqing \
  --use-remote-sudo
```

______________________________________________________________________

## 5. Developer Shell Inspection Tools (`nix/devshell.nix`)

Entering `nix develop` or running with `direnv` provides custom helper utilities:

| Command            | Purpose                                                                       |
| ------------------ | ----------------------------------------------------------------------------- |
| `host-tree <host>` | Interactive visualizer for system closure dependencies using `nix-tree`       |
| `host-size <host>` | Lists the top 25 largest packages in a host's system closure                  |
| `host-diff <host>` | Compares package changes between current generation and new build using `nvd` |
| `host-dead`        | Scans for dead code and statix linting warnings across the flake              |
| `dns-warm`         | Pre-warms the recursive Unbound DNS cache using top Majestic Million domains  |
| `diff-to-commit`   | Generates AI commit messages from staged Git diffs                            |
| `inspect <host>`   | Drops into an interactive Nix REPL with the host configuration loaded         |

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
