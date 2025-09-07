## NixOS flake (declarative overview)

### What this is
- **flake**: NixOS/home-manager setup for `x86_64-linux`
- **systems**:
  - `nixosConfigurations.fufuwuqi`: main server
  - `nixosConfigurations.wsl`: NixOS-WSL
- **style**: strictly declarative modules; secrets via `sops-nix`

### Key features
- **Networking**: `systemd-networkd`, `bond0` (active-backup), `wg0` (WireGuard), MTU tuned (1492/1380)
- **Firewall/NAT**: nftables firewall with mss clamp, NAT `bond0`⇄`wg0`
- **DNS**: AdGuard Home on :3333, parallel upstreams (Quad9/AdGuard/Google/Cloudflare)
- **Remote**: OpenSSH hardened, Google Authenticator PAM, Fail2ban jails
- **Reverse proxy**: Nginx vhosts for `*.local`, `*.vpn` (TLS via Cloudflare optional)
- **Containers**: Podman + dockerCompat, journald logs, overlayfs, default subnet pools
- **Tunnels**: `cloudflared` (token from sops)
- **Dev remote**: `openvscode-server` on VPN, `vscode-server` native module
- **AI/Compute**: ROCm stack and `services.ollama` (acceleration="rocm")
- **Server mode**: `serverMode.headless = true` disables GUI paths

### Layout
- **root**: `flake.nix`, `flake.lock`
- **nix/**: per-system entrypoints (`fufuwuqi.nix`, `wsl.nix`), devshell/formatter/hooks
- **modules/**: `boot`, `locale`, `packages`, `networking` (firewall/interfaces/tweaks), `services` (ssh, avahi, adguardhome, cloudflared, nginx, etc.), `server-mode`, `server-settings`
- **hardware/**: machine HW profile
- **users/**: `users.nix`, `home-*.nix`
- **secrets/**: `sops.nix` (points to `/etc/nixos/secrets/...`)

### Usage
- **enter dev shell**:
```bash
nix develop
```
- **format + lint (CI parity)**:
```bash
nix fmt -- --ci
nix flake check --print-build-logs
```
- **evaluate systems**:
```bash
nix eval --raw .#nixosConfigurations.fufuwuqi.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.wsl.config.system.build.toplevel.drvPath
```
- **build or switch (on target host)**:
```bash
# on fufuwuqi
sudo nixos-rebuild switch --flake .#fufuwuqi

# inside WSL instance
sudo nixos-rebuild switch --flake .#wsl
```

### Secrets (sops-nix)
- **age key paths**: `/etc/ssh/ssh_host_ed25519_key` and `/etc/nixos/secrets/key.txt`
- **default files**: `/etc/nixos/secrets/secrets.yaml`
- **declared secrets**: user passwords, `tokens/cloudflared` (mapped read-only into container)

### Notes
- **toggle GUI**: set `serverMode.headless = true|false` in `configuration.nix`
- **DNS clients**: system pref IPv6; AdGuard Home listens on `0.0.0.0`/`::`, rewrites for `*.vpn`, `*.lan`
- **Interfaces trusted**: firewall trusts `wg0` and `bond0`
- **ROCm**: ROCm path linked at `/opt/rocm`

### CI
- **GitHub Actions**: format/lint + flake check, then evaluate `fufuwuqi` and `wsl` in matrix

### License
- **GPL-3.0-only**: see `LICENSE`


