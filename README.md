## 福福的 NixOS 配置 ✨

[![lucky flake ci](https://github.com/categoricalcat/nixos/actions/workflows/flake-ci.yml/badge.svg?branch=main)](https://github.com/categoricalcat/nixos/actions/workflows/flake-ci.yml)

### Features

- Flake-based NixOS with `home-manager` modules
- Hosts: `fufuwuqi` (server, headless), `fuyidong` (laptop, GNOME), `fuchuang` (WSL)
- Opinionated modules: networking (systemd-networkd, WireGuard), server hardening, packages, fonts, locale
- Stylix theming (Catppuccin Mocha), GNOME/Niri selectable via option
- Services: OpenSSH (+2FA ready), AdGuard Home DNS, nginx, Podman, cloudflared tunnel, GitHub runner, VS Code Server
- Secrets via `sops-nix` (AGE/SSH), not stored in repo
- CI: format/lint + `flake check` + evaluate host derivations

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

- `passwords/fufud`, `passwords/workd`
- `tokens/cloudflared`, `tokens/playit-agent`, `tokens/github-runner-nixos`

### Hosts at a glance

| Host | Role | Environment | Highlights |
| --- | --- | --- | --- |
| `fufuwuqi` | Server (headless) | NixOS, systemd-networkd | WireGuard gateway, AdGuardHome, nginx, Podman, cloudflared, GitHub runner, VS Code Server |
| `fuyidong` | Laptop/desktop | GNOME (switchable to Niri) | WireGuard client, Home Manager, Stylix |
| `fuchuang` | WSL instance | NixOS-WSL | Minimal GUI, Home Manager |

### Desktop theming (Stylix)

Stylix is enabled when `desktop.environment` is `gnome` or `niri`. Fonts: Maple Mono NF CN + Noto Emoji. Base16: Catppuccin Mocha. Wayland/Electron ozone vars are set.

### CI

GitHub Actions (`.github/workflows/flake-ci.yml`):

- Check: `nix flake check --print-build-logs` and `nix fmt -- --ci`
- Evaluate: ensure each host derivation evaluates (`fufuwuqi`, `fuchuang`, `fuyidong`)

### License

GPL-3.0-only (see `LICENSE`).


