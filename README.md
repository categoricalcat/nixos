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
- Optimized TCP buffers (up to 128MB)
- SSH on port 24212 with 2FA (Google Authenticator)
- Open ports: 3000, 3001, 9000, 24212

### Software Stack

**System Tools**
- btop, tmux, screen, tree, fd
- fastfetch, curl, wget
- mtr (network diagnostic)

**Development**
- Emacs, VS Code (FHS)
- Git, GitHub CLI
- direnv, rclone
- nixfmt-rfc-style

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
cd /home/fufud/nixos
sudo nixos-rebuild switch --flake .#fufuwuqi

# Update flake inputs
nix flake update
```

## Structure

```
/home/fufud/nixos/
├── flake.nix              # Flake definitions
├── configuration.nix      # Main config for fufuwuqi
├── hardware/
│   └── hardware-configuration.nix
├── modules/
│   ├── boot.nix          # Bootloader & kernel
│   ├── desktop.nix       # GNOME/Wayland (when not headless)
│   ├── locale.nix        # Timezone & localization
│   ├── networking.nix    # Network bonding & firewall
│   ├── network-performance.nix
│   ├── packages.nix      # System packages
│   ├── server-mode.nix   # Headless toggle
│   ├── server-settings.nix
│   ├── services.nix      # SSH, code-server, etc.
│   └── wsl.nix          # WSL-specific config
└── users/
    ├── users.nix         # User accounts
    ├── home-fufud.nix    # fufud's home-manager
    └── home-workd.nix    # workd's home-manager
```

## Users

- **fufud**: Personal account with sudo, render, video, docker access
- **workd**: Work account with sudo, docker access

## Services

- SSH with hardened config and 2FA
- Code-server (VS Code in browser)
- USB serial console support (ttyUSB0)
- GnuPG agent with SSH support