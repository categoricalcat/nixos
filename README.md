## NixOS configuration flake

This repository contains a NixOS flake that defines a multi-host system configuration, reusable modules, declarative secrets with sops-nix, and a minimal CI workflow. It is structured for a personal homelab/server plus WSL and desktop hosts.

### High-level features

- **Flake-based topology**: `nixosConfigurations` for three hosts, shared modules, dev shell, formatter, and a standalone Home Manager config.
- **Secrets management**: `sops-nix` with age keys and per-service secret ownership.
- **Network-centric server**: systemd-networkd, WireGuard, bonding, nftables firewall/NAT, AdGuardHome DNS, Avahi/mDNS.
- **Container services**: Podman-backed `cloudflared` and `playit-agent` OCI containers.
- **Developer tooling**: VS Code Server and OpenVSCode Server, GitHub Actions checks, pre-commit hooks, formatter.

### Layout

```text
.
├── flake.nix                # Flake inputs/outputs (hosts, HM, devShells, formatter)
├── flake.lock
├── .github/workflows/ci.yml # CI: flake check, fmt, host evals
├── modules/                 # Reusable configuration modules
│   ├── desktop.nix
│   ├── fonts.nix
│   ├── locale.nix
│   ├── packages.nix
│   ├── server-mode.nix      # Headless mode gate (disables GUI services)
│   ├── server-settings.nix  # Power mgmt, journald limits, GC, smartd, chrony
│   └── networking/
│       ├── firewall.nix     # nftables, NAT, firewall ports and trusted interfaces
│       ├── interfaces.nix   # Imports bond0/wg0 and tweaks for specific NICs
│       ├── interfaces/bond0.nix
│       ├── interfaces/wg0.nix
│       └── tweaks.nix       # sysctl tuning (BBR, buffers, forwarding, zram)
├── modules/services/        # Service-specific modules
│   ├── adguardhome.nix      # DNS resolver with upstreams, rewrites, HTTP/3
│   ├── avahi.nix            # mDNS/Avahi advertising for SSH, HTTP(S), Cockpit, etc.
│   ├── cloudflared.nix      # Tunnel container (host networking) with sops token
│   ├── github-runner.nix    # Self-hosted GitHub Actions runner
│   ├── openssh.nix          # SSH hardening/tuning and listen addresses
│   ├── playit-agent.nix     # Playit tunnel container with sops token
│   └── services.nix         # Aggregates services, Podman config, Nginx vhosts
├── hosts/                   # Per-host NixOS configurations
│   ├── fuchuang/            # WSL host
│   │   └── configuration.nix
│   ├── fufuwuqi/            # Main server
│   │   ├── addresses.nix    # Central host/network/DNS/WG/SSH parameters
│   │   ├── boot.nix
│   │   ├── configuration.nix
│   │   └── hardware.nix
│   └── fuyidong/            # Desktop/VM host
│       ├── boot.nix
│       ├── configuration.nix
│       └── hardware.nix
├── nix/                     # Flake wiring and development utilities
│   ├── fuchuang.nix         # nixosSystem for WSL host
│   ├── fufuwuqi.nix         # nixosSystem for server
│   ├── fuyidong.nix         # nixosSystem for desktop/VM
│   ├── devshell.nix         # devShell with pre-commit integration
│   ├── formatter.nix        # treefmt + nixfmt + statix + deadnix
│   └── git-hooks.nix        # pre-commit hooks definitions
├── secrets/sops.nix         # sops-nix integration, users/groups for secrets
├── .sops.yaml               # sops creation rules and recipient keys
├── users/                   # User accounts and Home Manager configs
│   ├── users.nix            # `fufud` and `workd`, shells, services
│   ├── home-fufud.nix       # HM modules/packages for user fufud
│   └── home-workd.nix       # HM modules/packages for user workd
├── todo.md                  # Live improvement checklist (security, nginx, containers)
└── LICENSE                  # GPL-3.0
```

### Flake inputs

- **nixpkgs**: `nixos-unstable` for system packages and modules.
- **home-manager**: User-level configurations as Nix modules.
- **nixos-wsl**: WSL integration for the `fuchuang` host.
- **sops-nix**: Declarative secret provisioning via `age`.
- **nixos-vscode-server**: VS Code Server module.
- **nixowos**: Upstream module collection used across hosts.
- **treefmt-nix** and **git-hooks.nix**: Formatting and pre-commit integration.

### Flake outputs

- **`nixosConfigurations`**: `fuchuang` (WSL), `fufuwuqi` (server), `fuyidong` (desktop/VM).
- **`homeConfigurations`**: `standaloneHomeManagerConfig` referencing `nixowos`.
- **`formatter`**: treefmt wrapper configured for Nix formatting and linting.
- **`devShells`**: default dev shell with pre-commit hook support.

### Host focus areas

- **`hosts/fufuwuqi` (server)**
  - Kernel: latest packages, panic guards, AMD GPU enablement and ROCm userspace.
  - Networking: systemd-networkd; bonded LAN (`bond0`); VPN (`wg0`) with peers; static DNS selection; NAT; nftables MSS clamp.
  - Services: AdGuardHome DNS; nginx with local/vpn vhosts; OpenVSCode Server; VS Code Server; fail2ban; Ollama (ROCm); Avahi; Podman with tuned defaults; optional Cockpit disabled by default.
  - Security/ops: zram swap; smartd; periodic TRIM; journald size/retention limits; Nix GC; TPM2.

- **`hosts/fuchuang` (WSL)**
  - WSL module, headless server mode, OpenSSH, and Home Manager for user `fufud`.

- **`hosts/fuyidong` (desktop/VM)**
  - GNOME desktop module, fonts and locale modules, Home Manager for user `fufud`.

### Users and Home Manager

- **Users**: `fufud` (admin/personal) and `workd` (work). Immutable users, Zsh as default shell, Emacs service enabled.
- **Home Manager**: per-user package sets; repository cloning logic for `the.files` in activation hooks.

### Secrets and sops-nix

- **Age**: SSH host key path and age key file paths declared for decryption.
- **Secrets**: password files and service tokens, with explicit mode/owner/group and optional on-disk paths (e.g. `/etc/cloudflared/token`).
- **System users/groups**: `cloudflared`, `playit`, `github-runner` created for secret ownership and service isolation.

### Networking and security modules

- **Firewall and NAT**: nftables, open ports for DNS/HTTP(S)/SSH/WG/Minecraft, trusted interfaces `wg0`/`bond0`, and NAT from VPN to LAN.
- **Perf tuning**: sysctl for BBR, buffers, backlog, keepalives, and valid marks for containerized WireGuard.
- **OpenSSH**: address-bound listeners, auth method combination, rate limiting, cipher/KEX/MAC preference, forwarding options, and optimized defaults.

### Services overview

- **AdGuardHome**: DNS with multiple upstreams (Quad9, AdGuard, Google, Cloudflare), ECS/DNSSEC, caching, HTTP/3, and local rewrites for hostnames.
- **Avahi**: mDNS publishing on LAN/VPN (SSH, HTTP, HTTPS, Cockpit, custom ports).
- **Nginx**: basic local/vpn vhosts with minimal responses, ready for extension to public domains.
- **VS Code**: `services.vscode-server` and `services.openvscode-server` for development access.
- **Containers**: Podman with journald logging, ulimits, IPv6, MTU tuning, default subnet pools; `cloudflared` and `playit-agent` run as non-root users.
- **GitHub runner**: ephemeral self-hosted runner scoped to this repository.

### CI and formatting

- **CI workflow**: Checks out the repository, installs Nix, runs `flake check`, enforces formatting via `nix fmt`, and evaluates each host derivation.
- **Formatter and hooks**: treefmt wrapper with `nixfmt-rfc-style`, `statix`, and `deadnix`; pre-commit hooks for formatting and flake checks.

### License

Licensed under **GPL-3.0**. See `LICENSE` for details.

### Roadmap checklist

Ongoing improvements are tracked in `todo.md`, covering SSH tightening, nginx/Cloudflare reverse proxying, container auto-update/health, documentation, and system metrics.


