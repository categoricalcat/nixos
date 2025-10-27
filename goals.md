## NixOS flake goals and roadmap

This document lists high-impact improvements and feature ideas tailored to your current flake. Items are grouped by priority and area. Use the checkboxes to track progress.

### High priority (next 1–2 weeks)
- [ ] Switch `users.mutableUsers` to false and fully declarative users; move `fufud` password to sops
- [ ] Unify WireGuard config style (systemd-networkd vs NixOS module) across hosts; standardize MTU and routes
- [ ] Enable ACME with Cloudflare DNS-01 for `fufu.land` and subdomains; terminate TLS in nginx
- [ ] Add sshd jail to fail2ban; consider disabling `PasswordAuthentication` on WAN while keeping OTP on VPN/LAN
- [ ] Add system.autoUpgrade with flake pin and automatic GC (safe window) on all hosts
- [ ] Introduce basic monitoring: node_exporter + Prometheus + Grafana on `fufuwuqi`

### Security hardening
- [ ] SSH
  - [ ] Enforce publickey + OTP; disable `PasswordAuthentication` on public interfaces
  - [ ] Restrict `ListenAddress`/`GatewayPorts` to VPN/LAN where possible
  - [ ] Add `sshd` fail2ban jail and ban thresholds tuned for bots
- [ ] Secrets
  - [ ] Keep AGE key and sops files only at `/etc/nixos/secrets/`; ensure repo stays clean (verify `.gitignore`)
  - [ ] Per-host secrets files to minimize blast radius
- [ ] Kernel/sysctl
  - [ ] Cap inotify watches safely (`fs.inotify.max_user_watches`) and tune conntrack if running many containers
  - [ ] Consider `kernel.unprivileged_bpf_disabled=1` unless you need eBPF for tooling
- [ ] Accounts
  - [ ] Remove `extraUsers.tempd` or keep disabled; audit all users/groups
  - [ ] 2FA for sudo via PAM (optional)

### Networking and DNS
- [ ] DNS routing
  - [ ] Ensure hosts use AdGuard Home as the primary resolver via `systemd-networkd`/NM DHCP options
  - [ ] Serve DoH/DoT from AdGuard; keep upstreams load-balanced with fallback
- [ ] Firewall/NAT
  - [ ] Limit AdGuard UI (3333) to LAN/VPN only
  - [ ] Confirm NAT and MSS clamping are correct for all uplinks; evaluate IPv6 routing strategy (no NAT)
- [ ] WireGuard
  - [ ] Document peer onboarding; add per-peer subnets as needed (DNS split-horizon already in place)

### Observability and reliability
- [ ] Logging & metrics
  - [ ] Loki + Promtail for journald and nginx logs (retain 7–30 days)
  - [ ] Grafana dashboards for system, network, containers
- [ ] Backups
  - [ ] Restic or borgmatic for `/etc`, `/var/lib`, and important user data; schedule + prune policy
  - [ ] Offsite repository (rclone backend or object storage)
- [ ] Alerts
  - [ ] Alertmanager for disk, memory, service crash, and WireGuard tunnel down

### Container platform (Podman)
- [ ] Rootless Podman for `fufud` and `workd`; login helpers and per-user networks
- [ ] Local registry mirror/cache (optional) and image scanning (Trivy)
- [ ] Network policy: define user networks; restrict host networking where not required
- [ ] Implement `wg-easy` (password hash already in secrets) for quick peer management behind auth

### CI/CD
- [ ] CI speed and safety
  - [ ] Add cachix push on CI to reuse binaries between hosts
  - [ ] Add `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` to ensure builds, not only eval
  - [ ] Run `statix` and `deadnix` in CI explicitly (not only via formatter)
  - [ ] Matrix build for `nix flake check` and full build per host (allow fail-fast=false)
- [ ] Self-hosted runner
  - [ ] Constrain runner permissions; dedicated PAT with least privilege; ephemeral runner option
  - [ ] Add labels for architecture/features (e.g., `rocm`, `x86_64-linux`)

### Storage and filesystems
- [ ] Consider Btrfs on new installs for snapshots and fast rollback; enable periodic snapshots and `snapper`
- [ ] For server data, evaluate ZFS or Btrfs RAID1 with scrub + SMART alerts
- [ ] NFS
  - [ ] Switch to Kerberos (`sec=krb5p`) if you need stronger auth; otherwise document trust domain
  - [ ] Automount timeouts and retrans tuned per link; monitor for stale handle incidents

### Desktop experience (laptop/WSL)
- [ ] Hyprland/Niri session profiles; curate defaults (waybar, notifications, portal tweaks)
- [ ] GNOME extensions pinning and version checks; auto-disable on version mismatch
- [ ] Hardware
  - [ ] Resume reliability: verify kernel params on newer kernels; keep ThinkPad fixes only if still needed
  - [ ] Battery: refine TLP thresholds and platform profiles based on real usage

### Developer experience
- [ ] Devshell improvements: `just` or `make` commands for common tasks (fmt, check, build host)
- [ ] Attic (or nix-serve-ng) as a private shared binary cache between hosts
- [ ] Template `nix run` helpers: bootstrap secrets, verify VPN, lint

### Housekeeping
- [ ] Consistent module layering: per-area modules (security, networking, services) with host overlays only for deltas
- [ ] Document secrets layout and setup steps in `README.md` (AGE creation, key placement, host onboarding)
- [ ] Pin Stylix scheme via flake input or file to avoid accidental theme changes

---

#### Notes mapped to current flake
- Core pieces already solid: flakes, HM integration, Stylix, services stack, VPN mesh, CI boilerplate.
- Immediate wins are making auth fully declarative, enabling ACME, unifying WireGuard, and adding observability.


