# 福福的NixOS配置

Flake-based modular NixOS configuration for home server use with home-manager integration.

## Systems

- **fufuwuqi**: Main server configuration
- **wsl**: Windows Subsystem for Linux configuration

## Features

### Core
- NixOS unstable channel with flakes
- Home-manager for user-specific configurations
- Modular configuration structure
- AMD GPU support (ROCm, AMDVLK, OpenCL)

### Server Optimizations
- Power management disabled (24/7 operation)
- CPU governor: performance mode
- Weekly SSD TRIM and Nix garbage collection
- SMART disk monitoring
- Journal limited to 2GB with 1-month retention
- Headless mode toggle (`serverMode.headless`)

### Networking
- Dual NIC bonding (active-backup mode)
- BBR congestion control
- Optimized TCP buffers (up to 268MB)
- SSH on port 24212 with 2FA (Google Authenticator)
- WireGuard VPN (port 51820) with IPv4/IPv6 dual-stack
- IPv6 ULA prefix (fd00:100::/64) for VPN clients
- mDNS/Avahi for zero-config service discovery
- dnsmasq for VPN client DNS resolution
- Open ports: 25565 (Minecraft), 53 (DNS on VPN/LAN interfaces)
- Firewall allows mDNS (UDP 5353) and WireGuard (UDP 51820)

### Software Stack

**System Tools**
- btop, tmux, screen, tree, fd
- fastfetch, curl, wget, stow
- mtr (network diagnostic)
- ethtool, iperf3, nethogs, iftop
- nmap, traceroute
- kubectl, k6

**Development**
- Emacs, VS Code (FHS)
- Git, GitHub CLI
- direnv, rclone
- nixfmt-rfc-style, statix, deadnix
- nil (Nix language server)
- treefmt-nix integration

**Container Management**
- Podman ecosystem (podman, podman-compose, podman-tui)
- buildah, dive, skopeo

**Shell**
- Zsh with syntax highlighting and auto-suggestions
- Starship prompt
- fzf, zoxide

**Font**
- Maple Mono NF CN (monospace with NerdFont icons and Chinese support)

## Usage

```bash
# Build and switch to configuration
cd /etc/nixos
sudo nixos-rebuild switch --flake .#fufuwuqi

# Update flake inputs
nix flake update
```

## Structure

```
/etc/nixos/
├── flake.nix              # Flake definitions with treefmt-nix
├── flake.lock            # Pinned dependencies
├── configuration.nix      # Main config for fufuwuqi
├── .github/
│   └── workflows/
│       └── ci.yml        # CI/CD with nix flake check and formatting
├── hardware/
│   └── hardware-configuration.nix
├── modules/
│   ├── boot.nix          # Bootloader & kernel (IPv4/IPv6 forwarding)
│   ├── desktop.nix       # GNOME/Wayland (when not headless)
│   ├── locale.nix        # Timezone & localization (pt_BR.UTF-8)
│   ├── networking.nix    # Network bonding, firewall, WireGuard
│   ├── network-performance.nix  # TCP/network optimization
│   ├── packages.nix      # System packages
│   ├── server-mode.nix   # Headless toggle
│   ├── server-settings.nix  # Server-specific settings
│   ├── services/
│   │   ├── services.nix  # Main services configuration
│   │   ├── avahi.nix     # mDNS/zero-config discovery
│   │   ├── dnsmasq.nix   # DNS for VPN clients
│   │   └── openssh.nix   # SSH with 2FA and optimizations
│   └── wsl.nix          # WSL-specific config
├── users/
│   ├── users.nix         # User accounts
│   ├── home-fufud.nix    # fufud's home-manager
│   └── home-workd.nix    # workd's home-manager
└── todo.md               # Live improvement checklist
```

## Users

- **fufud**: Personal account with sudo, render, video, podman access
- **workd**: Work account with sudo, podman access

## Services

- **SSH** (port 24212): Hardened config with 2FA, optimized ciphers, port forwarding enabled
- **WireGuard VPN**: Dual-stack IPv4/IPv6 with dedicated DNS
- **Web Services**:
  - Nginx (basic hello world on port 80)
  - Code-server (VS Code in browser)
  - Cockpit (port 9090, currently disabled)
- **Network Services**:
  - dnsmasq: DNS server for VPN and LAN clients
  - Avahi: mDNS/zero-config service discovery
- **Container Runtime**:
  - Podman with Docker compatibility
  - Auto-pruning and journald logging
- **AI/ML**:
  - Ollama with ROCm acceleration for AMD GPUs
- **System Services**:
  - fail2ban: Intrusion prevention
  - fwupd: Firmware updates
  - Chrony: NTP time synchronization
- **Other**:
  - USB serial console support (ttyUSB0, disabled)
  - GnuPG agent with SSH support

## Development Features

- **CI/CD**: GitHub Actions workflow for flake checks and formatting
- **Code Quality**: treefmt-nix with nixfmt-rfc-style, statix, and deadnix
- **Flake Features**: nixowos integration for enhanced NixOS modules