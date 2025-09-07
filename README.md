# 福福的NixOS配置

- purpose: flake-based, modular NixOS for home server with Home Manager integration
- systems: `fufuwuqi` (server), `wsl` (WSL)
- mode: headless enabled (`serverMode.headless = true`)
- stateVersion: `25.11`
- link: see `nixos/todo.md` for open items

## Core

- nixpkgs: `nixos-unstable`
- modules: boot, networking, services, server-mode, server-settings, locale, packages, secrets (sops-nix)
- home-manager: enabled (`fufud`, `workd` on server; `fufud` on WSL)
- formatter/lint: `nixfmt-rfc-style`, `statix`, `deadnix` via `treefmt-nix`

## Networking

- stack: systemd-networkd, nftables, NAT
- bond0: `eno1` + `enp4s0` (active-backup, MTU 1492)
- lan: 192.168.1.42/24, gw 192.168.1.1
- vpn: WireGuard `wg0` 10.100.0.1/24, MTU 1380, port 51820
- dns (host): AdGuard Home on LAN/VPN/lo; upstreams = Quad9 + Google + Cloudflare; rewrites for `fufuwuqi.vpn` and `fufuwuqi`
- mdns: Avahi on `bond0` and `wg0`, advertises SSH/HTTP/HTTPS/WG-UI(51821)/Minecraft
- ipv6: enabled; forwarding on; selective RA settings
- tcp tuning: BBR, larger buffers, MSS clamp on forward

## Firewall / Ports

- trusted interfaces: `wg0`, `bond0` (full access including OpenVSCode Server on 4444)
- tcp open: 80, 443, 3333 (AdGuardHome UI), 24212 (SSH), 25565 (Minecraft)
- udp open: 25565 (Minecraft), 5353 (mDNS), 51820 (WireGuard)
- dns for clients: TCP/UDP 53 allowed on `bond0` and `wg0`
- note: Cockpit (9090) is commented out; OpenVSCode Server (4444) accessible only via trusted interfaces

## Services

- AdGuard Home: DNS with DNSSEC, HTTP/3, cache tuned, UI on 3333
- Nginx: minimal vhosts (`fufuwuqi.local`, `fufuwuqi.vpn`, `fufu.land`), TLS optional (currently disabled)
- cloudflared: Podman container, host network, token via sops at `/etc/cloudflared/token`
- OpenVSCode Server: enabled on 4444 (VPN IP only)
- VSCode Server: enabled for remote development
- ollama: enabled with ROCm acceleration
- chrony: NTP
- smartd: disk monitoring (non-WSL)
- fwupd: firmware updates
- cockpit: disabled (was on port 9090)

## Security

- OpenSSH: port 24212; 2FA (Google Authenticator); publickey + keyboard-interactive; hardened ciphers/KEX/MACs; forwarding enabled
- sops-nix: age-based secrets with `/etc/nixos/secrets/{secrets.yaml,key.txt}` and `.sops.yaml`
- fail2ban: nginx-related jails enabled
- TPM2: enabled
- journald: 2G cap, 1-month retention

## Containers (Podman)

- dockerCompat, socket, journald logging
- autoPrune: weekly, `--all`
- network: dns enabled, IPv6 enabled, MTU 1492; default subnet pools configured
- registries: docker.io, quay.io, ghcr.io

## Hardware / GPU

- amdgpu + AMDVLK + OpenCL
- ROCm packages: rocblas, hipblas, rocm-smi, rocminfo, rocmPath
- /opt/rocm symlink to `${rocmPath}`
- AMD microcode + redistributable firmware

## System

- kernel: latest; IPv4/IPv6 forwarding on
- power: performance governor; sleep/suspend/hibernate disabled
- storage: weekly fstrim; root `noatime,nodiratime`
- swap: ZRAM (zstd) at 75% memory
- fonts: Maple Mono NF CN as default mono/sans/serif
- nix-ld: enabled for VSCode Server compatibility

## Users

- accounts: `fufud` (wheel, render, video, dialout, podman), `workd` (wheel, dialout, podman)
- shell: zsh default; autosuggestions + syntax highlighting
- passwords: `workd` from sops; `fufud` secret present
- ssh agent: 15-minute timeout
- home-manager: user packages include Node.js variants; clones `the.files` on activation

## Dev / CI

- flake inputs: nixpkgs, home-manager, nixowos, treefmt-nix, pre-commit-hooks, sops-nix, nixos-wsl, vscode-server
- formatter output: treefmt wrapper exposed via `formatter`
- devshell: pre-commit hooks for `nix fmt -- --ci` and `nix flake check`
- ci workflow: `nix flake check`, `nix fmt -- --ci`, evaluation of `.#nixosConfigurations.{fufuwuqi,wsl}`

## Secrets (catalog)

- passwords: `passwords/{fufud,workd}`
- tokens: `tokens/cloudflared` (used)
- age key: `secrets/key.txt`; recipients in `.sops.yaml`
- note: ACME and ddclient tokens referenced in secrets.yaml but not configured in sops.nix

## Structure (selected)

- flake: `flake.nix`, `flake.lock`
- systems: `nix/fufuwuqi.nix`, `nix/wsl.nix`
- entry: `configuration.nix`
- modules: `modules/{boot,networking,services,server-mode,server-settings,locale,packages,addresses,wsl}.nix`
- networking: `modules/networking/{firewall,interfaces,tweaks}.nix`, `modules/networking/interfaces/{bond0,wg0}.nix`
- services: `modules/services/{services,openssh,avahi,adguardhome,cloudflared}.nix`
- secrets: `secrets/{sops.nix,secrets.yaml,key.txt}`, `.sops.yaml`
- users: `users/{users.nix,home-fufud.nix,home-workd.nix}`
- ci: `.github/workflows/ci.yml`
- dev: `nix/{devshell,formatter,pre-commit-hooks}.nix`
- todo: `todo.md`