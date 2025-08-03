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
- **USB Serial Console**: Access via USB-to-serial adapter (ttyUSB0)
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

## USB Serial Console

Connect a USB-to-serial adapter to access the console:

```bash
# From another computer
screen /dev/ttyUSB0 115200

# Or using minicom
minicom -D /dev/ttyUSB0 -b 115200
```

This provides emergency console access when network is unavailable.

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

## Node.js on NixOS

NixOS handles Node.js differently than traditional Linux distributions. Here's how to work with Node.js and npm packages on NixOS:

### System-wide Node.js

Node.js 20 LTS is installed system-wide. You can verify with:
```bash
node -v  # Should show v20.x.x
npm -v   # Should show npm version
```

### Global NPM Packages

**Important**: You cannot use `npm install -g` on NixOS due to the read-only file system.

Instead, global npm packages are managed through your NixOS configuration. The following are already installed:
- `pnpm` - Fast, disk space efficient package manager
- `eslint` - JavaScript linter
- `typescript` - TypeScript compiler
- `npm-check-updates` - Update package.json dependencies

To add more global packages, edit `packages.nix` and add them under `nodePackages`:
```nix
nodePackages.prettier
nodePackages.ts-node
```

### Per-Project Dependencies

For project-specific packages, use npm/pnpm normally:
```bash
# In your project directory
npm install express
pnpm add -D @types/node
```

### Managing Multiple Node.js Versions

For different Node.js versions per project, use `nix-shell`:

1. Create a `shell.nix` in your project:
```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    nodejs_18  # or nodejs_20, nodejs_22, etc.
    nodePackages.pnpm
  ];
}
```

2. Enter the shell:
```bash
nix-shell
node -v  # Will show the version specified in shell.nix
```

### Alternative: Using direnv

For automatic environment switching (like nvm), install `direnv`:

1. Add to `packages.nix`: `direnv`
2. Create `.envrc` in your project:
```bash
use nix
```
3. Allow direnv: `direnv allow`

Now when you `cd` into the project, it automatically loads the correct Node.js version! 

## SSH Port Forwarding

SSH port forwarding is enabled on this server. Here are the available options:

### Local Port Forwarding (Client → Server)
Forward a local port to a remote destination through the SSH server:
```bash
# Forward local port 8080 to remote_host:80 through SSH server
ssh -L 8080:remote_host:80 user@server -p 24212

# Forward local port 5432 to PostgreSQL on the SSH server
ssh -L 5432:localhost:5432 user@server -p 24212

# Bind to all interfaces (not just localhost)
ssh -L 0.0.0.0:8080:remote_host:80 user@server -p 24212
```

### Remote Port Forwarding (Server → Client)
Forward a remote port on the server back to your local machine:
```bash
# Make your local web server available on the remote server's port 8080
ssh -R 8080:localhost:3000 user@server -p 24212

# With GatewayPorts enabled, make it accessible from any interface
ssh -R 0.0.0.0:8080:localhost:3000 user@server -p 24212
```

### Dynamic Port Forwarding (SOCKS Proxy)
Create a SOCKS proxy for tunneling traffic:
```bash
# Create SOCKS proxy on local port 1080
ssh -D 1080 user@server -p 24212

# Then configure your browser/application to use SOCKS5 proxy at localhost:1080
```

### Persistent Port Forwarding
Add to your `~/.ssh/config`:
```
Host myserver
  HostName server-ip
  Port 24212
  User yourusername
  
  # Local forwarding
  LocalForward 8080 remote-host:80
  LocalForward 5432 localhost:5432
  
  # Remote forwarding
  RemoteForward 8080 localhost:3000
  
  # Dynamic forwarding
  DynamicForward 1080
```

Then connect with: `ssh myserver`

### Advanced: VPN over SSH
With `PermitTunnel` enabled, you can create a VPN:
```bash
# Requires root/sudo on both ends
ssh -w 0:0 root@server -p 24212
```

## Font Configuration

This system uses **Maple Mono SC NF** as the default monospace font. It's a beautiful open-source monospace font with:
- Round corners for better readability
- Programming ligatures
- NerdFont icons
- Full Chinese character support (Simplified Chinese, Traditional Chinese, and Japanese)

### Installed Fonts:
- **Maple Mono NF** - Base font with NerdFont icons (from nerd-fonts package)
- **Maple Mono SC NF** - With NerdFont icons and Chinese support
- **Noto Fonts CJK** - Comprehensive CJK (Chinese, Japanese, Korean) support
- **Source Han Sans/Serif** - Adobe's open source CJK fonts

### Font Family Names:
According to the official repository:
- `Maple Mono` - Base font
- `Maple Mono NF` - With NerdFont icons
- `Maple Mono SC` - With Simplified Chinese support
- `Maple Mono SC NF` - With both NerdFont and Chinese support (this is what we're using)

The installed packages provide both the NF and SC NF variants.

### Font Rendering:
The system is configured with:
- Antialiasing enabled
- Slight hinting for crisp text
- RGB subpixel rendering
- Optimized LCD filter

To verify the font installation after rebuilding:
```bash
fc-list | grep -i maple
```

## Configuration Structure

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

## USB Serial Console

Connect a USB-to-serial adapter to access the console:

```bash
# From another computer
screen /dev/ttyUSB0 115200

# Or using minicom
minicom -D /dev/ttyUSB0 -b 115200
```

This provides emergency console access when network is unavailable. 