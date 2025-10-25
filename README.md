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

Secrets are not committed. The module expects secrets at `/etc/nixos/secrets/` on each host.

Required paths (see `secrets/sops.nix`):

- `/etc/nixos/secrets/secrets.yaml` (SOPS data store)
- `/etc/nixos/secrets/key.txt` (AGE key file) — optional if using host SSH key

The config supports both an AGE key and the host SSH key:

- `sops.age.keyFile = "/etc/nixos/secrets/key.txt"`
- `sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]`

Secrets referenced by name include:

- **User Passwords**: `passwords/fufud`, `passwords/workd`
- **Service Tokens**: 
  - `tokens/cloudflared` - Cloudflare tunnel authentication
  - `tokens/playit-agent` - Game server tunnel service
  - `tokens/github-runner-nixos` - GitHub Actions self-hosted runner
  - `tokens/cloudflare-acme` - Let's Encrypt DNS validation (configured but disabled)
  - `tokens/wg-easy` - WireGuard management UI (in secrets.yaml)
- **Configurations**:
  - `ngrok/config` - Ngrok tunnel configuration

### Services

#### Core Services
- **SSH**: OpenSSH with Google Authenticator 2FA, custom port (24212), performance optimizations
- **Networking**: systemd-networkd, WireGuard VPN (10.100.0.0/24), network bonding for redundancy
- **DNS**: AdGuard Home with load-balanced upstream providers, custom rewrites

#### Web & Container Services
- **Web Server**: nginx with virtual hosts, reverse proxy ready
- **Container Platform**: Podman with Docker compatibility, auto-pruning, custom subnet pools
- **Tunnels**: Cloudflare tunnel (cloudflared), playit-agent for game server hosting
- **Development**: OpenVSCode Server (port 4444), VS Code Server, NFS shares

#### Security & Monitoring
- **Intrusion Prevention**: fail2ban with nginx jails
- **Secrets**: sops-nix with AGE/SSH keys
- **Firewall**: nftables with MSS clamping, NAT for VPN
- **Monitoring**: Avahi/mDNS for service discovery, smartd for disk health

#### AI/ML Services
- **Ollama**: AI model server with AMD ROCm acceleration

### Hosts at a glance

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

### Hardware Acceleration

- **fufuwuqi**: AMD GPU with ROCm (gfx1035 target) for Ollama AI acceleration
- **fuyidong**: Intel integrated graphics with VA-API support
- **Graphics Stack**: Full Wayland support with 32-bit compatibility

### Desktop Environments

#### GNOME (Primary)
- Wayland-native with experimental features (fractional scaling, VRR)
- Extensions: blur-my-shell, dash-to-dock, pop-shell, pano clipboard, media controls
- PipeWire audio with low-latency configuration
- Custom dconf settings via Home Manager

#### Niri
- Scrollable tiling Wayland compositor
- Integrated with Stylix theming
- Minimal resource usage

#### Hyprland
- Dynamic tiling compositor
- Full Wayland support
- Highly customizable

#### Theming (Stylix)
- **Theme**: Catppuccin Mocha (custom Base16 scheme)
- **Fonts**: Maple Mono NF CN (monospace), Lexend (sans), Noto Emoji
- **Applications**: Unified theming across GTK, Qt, terminals (Kitty, Alacritty)
- **Transparency**: Configurable for terminals and shell

### Development Features

- **Distributed Builds**: `fuyidong` offloads heavy builds to `fufuwuqi` via SSH
- **Binary Caches**: Configured for nix-community and nixos-rocm
- **Developer Tools**: Comprehensive suite including nil, statix, deadnix, direnv
- **Pre-commit Hooks**: Automated formatting and linting via git-hooks.nix
- **Shell Enhancement**: Zsh with autosuggestions, syntax highlighting, Starship prompt
- **Container Tools**: Podman with compose, TUI, dive, skopeo, buildah

### CI/CD

GitHub Actions (`.github/workflows/flake-ci.yml`):

- **Self-hosted Runner**: Configured on `fufuwuqi` for faster builds
- **Checks**: Format validation (`nix fmt -- --ci`), flake checks
- **Matrix Builds**: Parallel evaluation of all host configurations
- **Concurrency**: Smart cancellation of outdated workflow runs

### Future Improvements

Based on `todo.md`, planned enhancements include:

- **Security**: Disable SSH password authentication after confirming key+2FA setup; enable audit logs
- **Networking**: Optimize bonding parameters (relax `MIIMonitorSec`, add `UpDelaySec`/`DownDelaySec`)
- **Reverse Proxy**: Configure nginx with Cloudflare origin certificates for `fufu.land`
- **TLS**: Implement Cloudflare SSL in Full (strict) mode with proper certificate management
- **Container Management**: Enable `podman-auto-update` with healthchecks for critical services
- **Monitoring**: Add Cockpit metrics with PCP/pmlogger integration
- **Documentation**: Add architecture overview section explaining module relationships
- **Services**: Document or implement Minecraft server configuration (port 25565 is open)

### License

GPL-3.0-only (see `LICENSE`).


