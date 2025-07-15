# 福福的NixOS家用服务器配置方案

This repository contains a modular NixOS configuration optimized for home server use, running NixOS 25.05.

## Key Features

### Server Essentials
- **No Sleep/Suspend**: All power management disabled for 24/7 operation
- **Performance Mode**: CPU governor set to "performance"
- **Automatic Maintenance**: Weekly SSD TRIM and Nix garbage collection
- **Disk Monitoring**: SMART monitoring with console notifications
- **Time Sync**: Chrony NTP client for accurate time keeping
- **Journal Management**: Journal limited to 2GB with 1 month retention

### Headless Mode Option
Toggle between desktop and headless server modes:

```nix
# In configuration.nix - headless mode is currently enabled:
serverMode.headless = true;
```

When headless mode is disabled, the system runs GNOME on Wayland with auto-login for user "fufud".

### Network Configuration
- **Bonded Network**: Dual NIC bonding in active-backup mode
  - Primary: eno1 (Gigabit)
  - Secondary: enp4s0 (Currently 100 Mbps - check cable/switch)
- **Performance Tuning**: 
  - BBR congestion control
  - Optimized TCP buffers (up to 128MB)
  - TCP Fast Open enabled
  - SSH traffic QoS prioritization
- **Firewall**: Enabled with ports 3000, 3001, 9000, and 24212 (SSH) open

### Security & Access
- **SSH**: Hardened on port 24212
  - 2FA with Google Authenticator required
  - Public key + keyboard-interactive authentication
  - Root login disabled
  - Optimized ciphers for performance
  - Connection multiplexing enabled
- **Code Server**: VS Code in the browser enabled
- **Users**: Two users configured (fufud, work) with sudo access

## Configuration Files

```
/etc/nixos/
├── configuration.nix       # Main configuration file
├── boot.nix               # Bootloader & kernel settings
├── desktop.nix            # GNOME/Wayland desktop environment
├── hardware-configuration.nix # Auto-generated hardware config
├── locale.nix             # Timezone (São Paulo) and localization
├── networking.nix         # Network bonding and firewall
├── network-performance.nix # TCP/IP performance tuning
├── packages.nix           # System packages
├── server-mode.nix        # Headless mode toggle
├── server-settings.nix    # Server-specific optimizations
├── services.nix           # SSH, code-server, and other services
└── users.nix             # User accounts and Zsh configuration
```

## System Specifications

- **Boot**: systemd-boot with UEFI
- **Kernel**: Latest kernel package
- **Filesystem**: ext4 on NVMe with swap partition
- **Shell**: Zsh with Oh My Zsh (agnoster theme)
- **AMD CPU**: KVM-AMD virtualization enabled
- **GPU**: AMD with ROCm support enabled

## Installed Software

### System Utilities
- btop (system monitor)
- curl, wget
- fastfetch (displays on SSH login)
- ethtool, iperf3, nethogs, iftop (network tools)
- mtr (network diagnostic)

### Development Tools
- Emacs
- Git & GitHub CLI (gh)
- VS Code (FHS version)
- Node.js 20 (work user) and 24 (fufud user)
- nixfmt-rfc-style

### Security
- Google Authenticator (for SSH 2FA)
- GnuPG agent with SSH support

## Apply Changes

After making configuration changes:
```bash
sudo nixos-rebuild switch
```

## Maintenance Commands

```bash
# Check system status
systemctl status

# View failed services
systemctl --failed

# Check disk health
sudo smartctl -a /dev/nvme0n1

# Manual garbage collection
sudo nix-collect-garbage -d

# View journal size
journalctl --disk-usage

# Network performance test
iperf3 -c <server> # Test network throughput
ethtool bond0      # Check bonding status

# SSH connection test
ssh -p 24212 user@hostname
```

## Network Troubleshooting

The secondary network interface (enp4s0) is currently running at 100 Mbps instead of gigabit. To diagnose:

```bash
# Check link speed
ethtool enp4s0 | grep Speed
ethtool eno1 | grep Speed

# Check bonding status
cat /proc/net/bonding/bond0
```

## Security Notes

- SSH requires both public key and Google Authenticator 2FA
- Firewall is enabled - only specified ports are accessible
- No root login permitted via SSH
- Desktop auto-login is disabled in headless mode 

## Node.js Version Management with fnm

This configuration includes **fnm (Fast Node Manager)** as an alternative to nvm for managing Node.js versions on NixOS.

### Basic fnm Usage

After rebuilding your NixOS configuration, you can use fnm commands:

```bash
# List remote Node.js versions
fnm list-remote

# Install a specific Node.js version
fnm install 20.11.0
fnm install 18  # Install latest v18
fnm install --lts  # Install latest LTS

# List installed versions
fnm list

# Use a specific version
fnm use 20.11.0
fnm use 18

# Set a default version
fnm default 20.11.0

# Create .node-version file for project
echo "20.11.0" > .node-version
# fnm will automatically switch when you cd into the directory
```

### Per-Project Node.js Versions

fnm automatically switches Node.js versions when you enter a directory with a `.node-version` or `.nvmrc` file:

```bash
# In your project directory
echo "18.19.0" > .node-version
# Now when you cd into this directory, fnm will use Node.js 18.19.0
```

### Migration from nvm

If you have existing `.nvmrc` files from nvm, fnm will read them automatically. The commands are similar:
- `nvm install` → `fnm install`
- `nvm use` → `fnm use`
- `nvm list` → `fnm list`
- `nvm alias default` → `fnm default` 