## 福福的 NixOS 配置 ✨

[![lucky flake ci](https://github.com/categoricalcat/nixos/actions/workflows/flake-ci.yml/badge.svg?branch=main)](https://github.com/categoricalcat/nixos/actions/workflows/flake-ci.yml)

### Features

- **Core**: Flake-based NixOS with `home-manager` integration, `nixowos` modules
- **Hosts**: Three specialized machines - `fufuwuqi` (headless server), `fuyidong` (laptop), `fuchuang` (WSL)
- **Networking**: systemd-networkd, WireGuard VPN mesh, network bonding (bond0), Avahi/mDNS discovery
- **Storage**: NFS server/client with automounting, bind mounts for shared directories
- **Desktop**: GNOME/Hyprland/Niri support with Stylix theming (Catppuccin Mocha)
- **Services**: Comprehensive service stack including web, container, development, and AI/ML
- **Security**: `sops-nix` secrets management (AGE/SSH), fail2ban, 2FA SSH, nftables firewall
- **Development**: Distributed Nix builds, GitHub Actions runner, pre-commit hooks
- **Hardware**: AMD ROCm GPU acceleration, Intel GPU support, TPM2, battery optimization (TLP)
- **CI/CD**: Automated formatting, linting, flake checks, and host evaluation

### Layout

- `flake.nix`, `flake.lock`: inputs, outputs, hosts, devshell, formatter
- `nix/`: host entrypoints that assemble modules for each machine
  - `fufuwuqi.nix`, `fuyidong.nix`, `fuchuang.nix`
- `hosts/<host>/`: host-specific modules (boot, hardware, networking, services)
- `modules/`: reusable modules (desktop, networking, services, server-mode, server-settings, fonts, locale, packages)
- `users/`: Home Manager configs and user definitions
- `secrets/`: sops-nix module and example secrets (real secrets live outside the repo)
- `.github/workflows/flake-ci.yml`: CI for checks and evaluation

### Secrets (sops-nix)

Secrets are not committed. The module expects secrets at `/etc/nixos/secrets/` on each host. The config supports both an AGE key and the host SSH key:

- `sops.age.keyFile = "/etc/nixos/secrets/key.txt"`
- `sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]`

### Services

- **SSH**: OpenSSH with Google Authenticator 2FA, custom port (24212), performance optimizations
- **Networking**: systemd-networkd, WireGuard VPN (10.100.0.0/24), network bonding for redundancy
- **DNS**: AdGuard Home with load-balanced upstream providers, custom rewrites
- **Web Server**: nginx with virtual hosts, reverse proxy ready
- **Container Platform**: Podman with Docker compatibility, auto-pruning, custom subnet pools
- **Tunnels**: Cloudflare tunnel (cloudflared), playit-agent for game server hosting
- **Development**: OpenVSCode Server (port 4444), VS Code Server, NFS shares
- **Intrusion Prevention**: fail2ban with nginx jails
- **Secrets**: sops-nix with AGE/SSH keys
- **Firewall**: nftables with MSS clamping, NAT for VPN
- **Monitoring**: Avahi/mDNS for service discovery, smartd for disk health
- **Ollama**: AI model server with AMD ROCm acceleration

### Hosts

| Host | Role | Hardware | Network | Key Services |
| --- | --- | --- | --- | --- |
| `fufuwuqi` | Headless server | AMD CPU, ROCm GPU (gfx1035), NVMe | Bonded NICs (bond0), WireGuard hub | NFS server, Ollama, Podman, all web services |
| `fuyidong` | Laptop/desktop | Intel CPU/GPU, Thunderbolt | WiFi, WireGuard client | GNOME desktop, distributed build client, TLP power management |
| `fuchuang` | WSL instance | Virtual | WSL networking | Development environment, minimal services |

### Networking Architecture

- **VPN Mesh**: WireGuard network (10.100.0.0/24) connecting all hosts
  - `fufuwuqi` (10.100.0.1): VPN hub/gateway with NAT
  - `fuyidong` (10.100.0.2): Client via persistent keepalive
  - `fuchuang` (10.100.0.3): WSL client
- **LAN**: Primary network (192.168.1.0/24) with static IPs
- **Bonding**: `bond0` interface combining `eno1` + `enp4s0` for redundancy
- **systemd-networkd**: Declarative network configuration with MTU optimization (1492)
- **Service Discovery**: Avahi/mDNS advertising SSH, HTTP/HTTPS, Minecraft, and custom services

#### Theming (Stylix)
- **Theme**: Catppuccin Mocha (custom Base16 scheme)
- **Fonts**: Maple Mono NF CN (monospace), Lexend (sans), Noto Emoji
- **Applications**: Unified theming across GTK, Qt, terminals (Kitty, Alacritty)
- **Transparency**: Configurable for terminals and shell

### CI/CD

GitHub Actions (`.github/workflows/flake-ci.yml`):

- **Self-hosted Runner**: Configured on `fufuwuqi` for faster builds
- **Checks**: Format validation (`nix fmt -- --ci`), flake checks
- **Matrix Builds**: Parallel evaluation of all host configurations
- **Concurrency**: Smart cancellation of outdated workflow runs
