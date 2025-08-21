## NixOS Improvement Checklist (live)

### Quick wins

- [ ] Secure Cockpit with TLS via `security.acme` and/or reverse proxy in `services.nginx`; set `AllowUnencrypted = false`; restrict `allowed-origins`.
- [ ] SSH: set `PasswordAuthentication = no` once keys+2FA are confirmed; optionally add `Match` blocks to restrict by `AddressFamily`/`From`.
- [x] README: fix path to `/etc/nixos` and add brief usage notes for flake builds.
- [x] Remove `docker` group from users; keep `podman` only.
- [x] WSL: deduplicate `nixowos.nixosModules.default` import.

### Security

- [ ] Integrate `sops-nix` or `agenix` for secrets (WireGuard keys, future tokens).
  - Setup steps for SSH key-based sops-nix:
    1. Add `sops-nix` input to flake.nix
    2. Create `modules/secrets.nix` with `age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]`
    3. Install sops, age, ssh-to-age packages
    4. Create `.sops.yaml` with age keys from `ssh-to-age`
    5. Create `secrets/secrets.yaml` with `sops secrets/secrets.yaml`
    6. Update services to use `config.sops.secrets."name".path`
- [ ] Fail2ban: add nginx/cockpit jails if exposing HTTP(S); tune bans.
- [x] SSH: keep 2FA, `MaxAuthTries = 3`, `LoginGraceTime = 30s` (already present/close; re-validate values).
- [ ] Enable audit logs: `security.auditd.enable = true` and consider basic audit rules.

### Networking

- [x] Decide DNS strategy: enable `services.resolved` or go dnsmasq-only; avoid hand-managed `resolv.conf` unless required; document container/VPN DNS.
- [x] Import `modules/services/dnsmasq.nix` for VPN-scoped DNS on `wg0`.
- [x] WireGuard: consider an IPv6 ULA prefix for clients and Router Advertisements; validate firewall for IPv6. (Using fd00:100::/64)
- [x] Enable mDNS/Avahi for zero-config service discovery across VPN and LAN with service advertisements.
- [ ] Bonding: relax `MIIMonitorSec` to ~1s and add modest `UpDelaySec`/`DownDelaySec` to reduce flapping.
- [x] Replace static `resolv.conf` with `services.resolved` integrated with `systemd-networkd`; document DNS fallbacks and DoT if desired.
- [ ] Add log rotation for `/var/log/dnsmasq-vpn.log` via `services.logrotate`.

### Containers (Podman)

- [x] Switch container log driver to `journald` for central logging.
- [ ] Consider `podman-auto-update` with units/healthchecks for long-running services.
- [ ] Re-validate MTU 1492 end-to-end (bond0 ↔ WAN ↔ VPN/containers) and document rationale.
- [ ] Enable `virtualisation.podman.autoUpdate.enable = true;` and add healthchecks in units/compose for critical containers.
- [ ] Set `events_logger = "journald"` in `containers.conf` for complete journal integration.

### Performance and reliability

- [ ] Add `boot.loader.systemd-boot.configurationLimit = 10`.
- [ ] Add kernel safety nets: `kernel.panic = 10`, `kernel.panic_on_oops = 1`.
- [ ] Raise inotify limits for dev/containers: `fs.inotify.max_user_watches`/`max_user_instances`.
- [ ] Rate-limit journald bursts: `RateLimitIntervalSec=30s`, `RateLimitBurst=1000`.

### Nix / Flakes / DevEx

- [x] Add pre-commit with `statix`, `deadnix`, and one formatter (`nixfmt-rfc-style` or `alejandra`) via `treefmt-nix`.
- [x] CI: run `nix flake check`, build `.#nixosConfigurations.{fufuwuqi,wsl}`, and lint (`statix`, `deadnix`).
- [x] DevShell with `nil` (Nix LSP), lint tools, and `pre-commit`.

### Documentation

- [ ] Add a short Architecture section (boot, networking, services, server-mode; how `serverMode.headless` gates features).
- [ ] Keep a minimal `CHANGES.md` for operational changes (ports, exposure, services).
- [x] Update README `Users` section to reflect `podman` (not `docker`) access.

### Cleanup and consistency

- [ ] Remove duplicate `programs.mtr.enable` (present in both `users/users.nix` and `modules/services/services.nix`).
- [ ] Clarify/remove unused overlay `androidndkPkgs_23b`.

### System-specific

- [x] Enable `security.tpm2` and `services.fwupd` for firmware updates.
- [x] Ensure `hardware.enableRedistributableFirmware = true;` so AMD microcode updates apply.
- [ ] Cockpit metrics: enable `services.pcp` and optionally `services.pmlogger`.
- [ ] Document or implement Minecraft server setup (port 25565 is open).
